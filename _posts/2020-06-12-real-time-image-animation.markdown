---
title:  "How to bring image to life using machine learing"
excerpt: "Playing with ML model to animate image using Pytorch, Python and Jupyter"
header:
  overlay_image: /assets/images/post_teaser.jpeg
  overlay_filter: 0.5 # same as adding an opacity of 0.5 to a black background
  caption: "Photo credit: [Markus Spiske](http://freeforcommercialuse.net)"
date:   2020-02-09 14:52:00 +0200
tags: jupyter neural-netowrk python opencv 
---
Machine learning today allows you to achieve very interesting effects. Probably everyone has heard about [Deepfake] (https://en.wikipedia.org/wiki/Deepfake). In today's post I wanted to show you how much this technology is available for everybody this days.

Using my repository you will be able to create face image animations using the image of your face recorded in real time on the camera:
[Animation from webcam]({{ site.url }}/assets/images/animate_from_webcam.gif )

...or to create face image animations using the previously created video of your face:
[Animation from video]({{ site.url }}/assets/images/animate_from_video.gif )

In this post I will show the code from my repository [real-time-image-animation-docker] (https://github.com/k0staa/real-time-image-animation-docker) but I would not created that without other people's work. Projects I used:

[AliaksandrSiarohin/first-order-model](https://github.com/AliaksandrSiarohin/first-order-model)

[anandpawara/Real_Time_Image_Animation](https://github.com/anandpawara/Real_Time_Image_Animation)

Machine learning model used in the program was described in paper:
```
@InProceedings{Siarohin_2019_NeurIPS,
  author={Siarohin, Aliaksandr and Lathuilière, Stéphane and Tulyakov, Sergey and Ricci, Elisa and Sebe, Nicu},
  title={First Order Motion Model for Image Animation},
  booktitle = {Conference on Neural Information Processing Systems (NeurIPS)},
  month = {December},
  year = {2019}
}
```

### Short explanation on how the model works
[ML model ]({{ site.url }}/assets/images/real-time-image-anim-model.png )
In short, the model decouples appearance and motion information using a self-supervised formulation. To support complex motions, it uses a representation consisting of a set of learned keypoints along with their local affine transformations. At the end it combines the appearance extracted from the source image with the motion derived from the video.

I encourage you to watch the video of one of the authors of the model.
[![First Order Motion Model for Image Animation](https://img.youtube.com/vi/u-0cQ-grXBQ/0.jpg)](https://www.youtube.com/watch?v=u-0cQ-grXBQ)

### How to run project
In order to run the project you need to have Docker installed on your machine. I have been tested this project using Docker 19.03.10 version with `nvidia-container-toolkit 1.1.2-1` (if you don't have CUDA compatible graphics card you don't need `nvidia-container-toolkit`). 
It's best if you have CUDA compatible graphics card and Docker with CUDA capabilities but don't worry if you haven't :smiley: , you can still run the project and use image animation but **not in realtime**. Making predictions without CUDA is just too slow.

To build image please run:
```
./build.sh
```
...and then you can run container using (CUDA):
```
./run.sh
```
...or using (CPU):
```
./run_no_cuda.sh
```
You should see link to jupyter notebook in terminal, something like this:
```
http://127.0.0.1:8888/?token=edb9623d6c4ff0eac3096f88bb53ed1f3cfefdd9468f06ab
```
After you open the Jupyter please run `demo.ipynb` notebook. I will explain few things here but you can also follow instructions and notes included in jupyter notebook.

### Quick explanation of notebook sections
#### Load imports and setup
It's one important thing here aprat from imports. Please set `USE_CPU` to `False` if you don't have CUDA compatible graphic card.

#### Choose source image
In this section you have to choose the image to be animated. You can choose anyone available in the `source_image_inputs` folder or upload your own image and put it in this folder. Remember that it's best if the image has the following specifications:
1. square proportions
2. the background has an even color
3. the face is clearly visible

#### Create a model and load checkpoints
We use a trained model here so we have to download it. I have created a function that will automatically download the model and extract it to the `extract` folder if it does not already exist.

#### Record your source video
Now is the time to record the video that will be used to animate the previously selected photo. You can skip that and use video that I provieded in repository (`temp/test_video_cropped.avi`), if you wan't that please jump to **Resizing source video and image** section. You can also skip creating animation from prepared video and go straight to the **Real time image animation** section from here and try real time animation!

#### Crop and scale video
Recorded video need to be croped and scaled so only your face will be visible in it. The library [1adrianb/face-alignment] (https://github.com/1adrianb/face-alignment) is used to search for the right area to crop in video. After running the `CropVideo` method and `print (commands)`, the corresponding parameters for the `ffmpeg` program, will be displayed:
```
['ffmpeg -i temp/source_video.avi -ss 0.0 -t 7.090909090909091 -filter:v "crop=293:294:147:120, scale=256:256" crop.mp4']
```
You need to move crop parameters to the next cell where `ffmpeg` is run. So in this example you need to take `293`,`294`,`147`,`120` and set `ffmped` like that:
```
(ffmpeg
.input(saved_video_file_name)
.filter('crop', out_w='293', out_h='294', x='147', y='120')
.filter('scale', size='256:256', force_original_aspect_ratio='disable')
.output("temp/source_video_cropped.avi")
.overwrite_output()
.run()
)
```
This process can be slow when you not using CUDA...

#### Resizing source video and image 
Both video and source image is resized to 256x256.

#### Perform image animation
In this section, we will do animation using the model. There are two important parameters which can produce different results:
- `relative` - if set to `True` it is using relative keypoint displacement and if set to `False` it is using absolute coordinates. Using absolute coordinates, there are no special requirements for the source video and the appearance of the source image. However, as mentioned by author of the model this usually leads to poor performance, because irrelevant details such as shape are transferred. So using relative coordinates it's usually better but requires that the object in the first frame of the video and in the source image have the same pose. 
- `adapt_movement_scale` - if set to `True` 

I leave three combinations from original project and you can do all of them and choose the best. All resulting recordings are saved in `temp` folder.

#### Save animation result with source video and possibly convert to GIF
You can create video file with source image and animation and also convert it to GIF. It will look lie this:
[Animation from video]({{ site.url }}/assets/images/animate_from_video.gif )

#### Real time image animation
Here is the coolest part. You can do animation in real time. The camera image is croped and scaled in real time using OpenCV. The result is visible in frame and also recorded to a file.

### Summary
You can find all the source code in my repository [GitHub account](https://github.com/k0staa/real-time-image-animation-docker). And don't forget to give some :star2: to authors of other projects mentioned in the beggining ! 
Have fun and thanks for reading!
