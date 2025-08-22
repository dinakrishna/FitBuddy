# Laser Point Detection Logic

This Flutter app implements a simple real-time laser point detection game using the device camera. The detection logic is as follows:

## Detection Steps

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

## Notes

- The detection logic is lightweight and works offline.
- Only one circle is drawn per frame, at the most likely laser spot.
- The code is modular and ready for more advanced detection logic in the future.
# fitbuddy

A new Flutter project.
