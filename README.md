
# Laser Point Detection Logic

This Flutter app implements real-time laser point detection using two methods:

## 1. Single Brightest Pixel Method

1. **Camera Frame Input:**
	- The app receives camera frames in YUV or RGB format using the `camera` plugin.
2. **Pixel Scanning:**
	- Each frame is scanned for pixels where the red channel is significantly higher than the green and blue channels (simulating a laser spot).
	- Only pixels with red > 180, and red at least 60 greater than green and blue, are considered as candidates.
3. **Brightest Candidate Selection:**
	- Among all candidate pixels, the one with the highest red value (brightness) is selected as the laser point.
4. **Overlay Drawing:**
	- A circle is drawn at the coordinates of the brightest candidate pixel in the camera preview.
	- If no candidate pixel is found, no circle is drawn.
5. **Debug Logging:**
	- The bottom of the app displays a scrollable debug log showing frame number, average brightness, candidate pixels, and the chosen laser point.

## 2. Blob Detection (Multiple Red Objects)

1. **Camera Frame Input:**
	- The app receives camera frames in YUV or RGB format using the `camera` plugin.
2. **Pixel Scanning:**
	- All pixels meeting the red threshold are collected as candidates.
3. **Blob Grouping:**
	- Candidate pixels are grouped into blobs based on proximity (distance threshold).
	- Each blob represents a distinct red object in the frame.
4. **Centroid Calculation:**
	- For each blob, the average (mean) x and y coordinates are calculated to find the blob's center.
5. **Overlay Drawing:**
	- A circle is drawn at the center of each detected blob in the camera preview.
	- Multiple red objects will each be marked with a circle.
6. **Debug Logging:**
	- The debug log shows the number of blobs detected and their positions.

## Notes

- Both methods work offline and are lightweight.
- The code is modular and ready for more advanced detection logic (e.g., OpenCV integration).
# fitbuddy

A new Flutter project.
