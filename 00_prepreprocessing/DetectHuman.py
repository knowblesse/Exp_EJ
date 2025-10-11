import queue
from queue import Queue
from threading import Thread
import numpy as np
from pathlib import Path
import cv2 as cv
import time
import pickle
import matplotlib.pyplot as plt
from tkinter.filedialog import askdirectory
from tqdm import tqdm

# Setup the ROI
def paintROI(image, initialState=False):
    """
    left paint : Select
    right paint : Deselect
    mouse wheel : change brush size
    """
    image_orig = image.copy()
    height = image.shape[0]
    width = image.shape[1]
    mask = np.logical_or(np.zeros((height, width), dtype=bool), initialState)
    state = {'button': 0, 'brushSize': 4, 'currentPosition': [0, 0]}  # 0: no button, 1: left, 2: right

    def mouseCallBack(event, x, y, f, state):
        if event == cv.EVENT_LBUTTONDOWN:
            state['button'] = 1
        elif event == cv.EVENT_MOUSEMOVE:
            state['currentPosition'] = [x, y]  # for brush size box
            if state['button'] == 1:
                mask[
                max(0, y - state['brushSize']):min(height, max(0, y + state['brushSize'])),
                max(0, x - state['brushSize']):min(width, max(0, x + state['brushSize']))] = True
            elif state['button'] == 2:
                mask[
                max(0, y - state['brushSize']):min(height, y + state['brushSize']),
                max(0, x - state['brushSize']):min(width, x + state['brushSize'])] = False

        elif event == cv.EVENT_LBUTTONUP:
            state['button'] = 0
        elif event == cv.EVENT_RBUTTONDOWN:
            state['button'] = 2
        elif event == cv.EVENT_RBUTTONUP:
            state['button'] = 0
        elif event == cv.EVENT_MOUSEWHEEL:
            if f < 0:
                state['brushSize'] = state['brushSize'] + 1
            else:
                state['brushSize'] = max(0, state['brushSize'] - 1)

    cv.namedWindow('Paint ROI')
    #self.isPaintROIOpen = True
    cv.setMouseCallback('Paint ROI', mouseCallBack, state)
    key = -1
    while key == -1:
        image = image_orig.copy()
        image[mask, 0] = np.round(image[mask, 0] * 0.9)
        image[mask, 1] = np.round(image[mask, 1] * 0.9)
        image[mask, 2] = 255
        cv.rectangle(image,
                     (state['currentPosition'][0] - state['brushSize'],
                      state['currentPosition'][1] - state['brushSize']),
                     (state['currentPosition'][0] + state['brushSize'],
                      state['currentPosition'][1] + state['brushSize']),
                     thickness=1,
                     color=(0, 0, 0))
        cv.imshow('Paint ROI', image)
        key = cv.waitKey(1)
    cv.destroyWindow('Paint ROI')
    #self.isPaintROIOpen = False
    return mask

def createTrialSmi(video_path):
    #video_path = Path(r"D:\Data\Kim Data\AP18_031418\")
    print(video_path)
    vc = cv.VideoCapture(str(video_path.absolute()))
    ret, frame = vc.read()
    if not ret:
        raise IOError("Can not read the first frame from the video")

    # Set queue for video reading thread
    frameQ = Queue(maxsize=500)

    # Setup a function for multithreading
    #global_mask = paintROI(frame, initialState=False)
    # with open('global_mask.pk', 'wb') as f:
    #     pickle.dump(global_mask, f)
    with open('global_mask.pk', 'rb') as f:
        global_mask = pickle.load(f)

    def storeFrames(stride=5):
        # Rewind the play header
        vc.set(cv.CAP_PROP_POS_FRAMES, 0)
        if vc.get(cv.CAP_PROP_POS_FRAMES) != 0:
            raise(BaseException('Can not set the play header to the beginning'))
        cur_header = 0

        # Read and save frames
        while True:
            if not frameQ.full():
                ret, frame = vc.read()
                if ret == False:
                    # This is the end of the frame. num_frame is wrong!
                    print(f'Done Reading')
                    break
                frameQ.put((cur_header, frame))
                cur_header += 1
                # skip other frames
                for i in range(stride-1):
                    ret = vc.grab()
                    cur_header += 1
            else:
                time.sleep(0.1)

    # Start a new Thread
    stride = 5
    videoReaderThread = Thread(target=storeFrames, args=(stride,))
    videoReaderThread.daemon = False # this is a helper thread, not main.
    if not videoReaderThread.is_alive():
        videoReaderThread.start()

    # Run through stored frames
    data = np.zeros((int(np.ceil(vc.get(cv.CAP_PROP_FRAME_COUNT)/stride)),2))
    index = 0

    progressBar = tqdm(range(int(data.shape[0])))
    for obj in progressBar:
        #while not(frameQ.empty()) or videoReaderThread.is_alive():
        try:
            frame_number, frame = frameQ.get(timeout=5)
        except queue.Empty:
            break
        frame_ = cv.bitwise_and(frame, frame, mask=np.uint8(global_mask))
        data[index, 0] = frame_number
        data[index, 1] = np.sum(frame_) / np.sum(global_mask)
        index += 1

    threshold = np.median(data[:,1]) + np.std(data[:,1])*2

    peaks = []
    noPeakCoolDownCounter = 0
    inPeak = False
    for idx, point in enumerate(data):
        if not inPeak:
            if point[1] > threshold:
                inPeak = True
                peaks.append(idx)
                noPeakCoolDownCounter = 20
        else:
            if point[1] < threshold:
                if noPeakCoolDownCounter > 0:
                    noPeakCoolDownCounter = noPeakCoolDownCounter - 1
                else:
                    inPeak = False

    peaks = np.array(peaks, dtype=int)


    smiStartString = """
    <SAMI>
    <HEAD>
    <TITLE>Neuralynx Video Timestamp</TITLE>
    <STYLE TYPE="text/css">
    <!--
    P {
    font-size:1.2ems;
    font-family: Arial;
    font-weight: normal;
    color: #FFFFFF;
    background-color: #000000;
    text-align: center;
    }
    .ENUSCC { name: English; lang: EN-US-CC; }
    -->
    </STYLE>
    </HEAD>
    <BODY>
    """
    fps = vc.get(cv.CAP_PROP_FPS)
    with open(video_path.parent / (str(video_path.stem)+'_trial.smi'), 'w') as f:
        f.writelines(smiStartString)
        for idx, peak in enumerate(peaks):
            f.write(f'<SYNC Start={int(data[peak,0]/fps*1000 - 500):d}><P Class=ENUSCC>ID%{idx}%</SYNC>\n')
            #f.write(f'<SYNC Start={int(data[peak,0]/fps*1000 + 500):d}><P Class=ENUSCC>&nbsp</SYNC>\n')

        f.write('</BODY>\n</SAMI>')
    print(f'Total SMI : {peaks.shape[0]}')
createTrialSmi(next(Path(askdirectory()).glob('*.mpg')))