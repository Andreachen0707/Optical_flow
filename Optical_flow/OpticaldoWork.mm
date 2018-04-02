//
//  OpticalDowork.m
//  gmv_opt
//
//  Created by Andrea Chen on 2/9/18.
//  Copyright © 2018 Andrea Chen. All rights reserved.
//
#import "GTCaptureOutputUtils.h"
#import "OpticaldoWork.h"
#import <AVFoundation/AVFoundation.h>

using namespace cv;

@implementation OpticaldoWork
cv::Size                    _winSize;
cv::TermCriteria            _termcrit;


cv::Mat image;
cv::vector<uchar>               status;
cv::vector<float>               err;


//These four component should be global
bool _addRemovePt = true;
cv::vector<cv::Point2f> points[2];
Mat gray;
Mat gray_prev;


//vector for all input GMV results
cv::vector<Point2f> _GMVPointall;

// Input: GMVinputPoints: correct detection results from GMV
//        CurrentFrame: coordinate frame with the correct results
//        Update: whether there is a new result come in
+(void)OFReceiveExactProcessorPoints: (NSArray<CGPoint>) points :(UIImage) currentFrame
{
    
    //For Adam:
    //I don't thing we need to have 'currentFrame' for storing the correct points,
    //instead, we can set a global flag to tell whether the optical flow need to check with correct result
    cv::Point2f point_0,point_1,point_2,point_3;
    //put GMV results into vector, for further compute
    for(NSValue * value in points){
        CGPoint point = [value CGPointValue];
        //give each point four partners
        point_0 = cv::Point2f(point.x-10,point.y);
        point_1 = cv::Point2f(point.x+10,point.y);
        point_2 = cv::Point2f(point.x,point.y-10);
        point_3 = cv::Point2f(point.x,point.y+10);
        
        _GMVPointall.push_back(cv::Point2f(point.x,point.y));
        _GMVPointall.push_back(cv::Point2f(point_0.x,point_0.y));
        _GMVPointall.push_back(cv::Point2f(point_1.x,point_1.y));
        _GMVPointall.push_back(cv::Point2f(point_2.x,point_2.y));
        _GMVPointall.push_back(cv::Point2f(point_3.x,point_3.y));
        
    }
    
    //if we need to give the result to optical flow to check
    _addRemovePt = true;
    
    
}
+(NSArray*)OFDoWorkAndProducePoints :(UIImage)currentFrame
{
    NSArray* newPoints;
    _winSize = cv::Size(15,15);
    _termcrit = cv::TermCriteria(cv::TermCriteria::EPS|cv::TermCriteria::COUNT,20,0.01);
    
    
    //convert UIimage to opencv gray mat
    gray =* [GTCaptureOutputUtils cvMatFromImage:currentFrame gray:true];
   
    //These mats should be global.
    //Mat gray;
    //Mat gray_prev;
    
    
    if (!points[0].empty())
    {
        cv::vector<uchar> status;
        cv::vector<float> err;
        
        if(gray_prev.empty())
        {
            gray.copyTo(gray_prev);
        }
        
        calcOpticalFlowPyrLK(gray_prev, gray, points[0],points[1], status, err, _winSize, 3, _termcrit, 0, 0.001);
        
        size_t i;
        //if new result comes in, then check with the tracking results, else just do tracking
        
        for(i = 0; i<_GMVPointall.size();i++)
        {
            if(_addRemovePt)
            {
                if( _GMVPointall[i]==cv::Point2f(288,-80)){
                    continue;
                }
                if(norm(_GMVPointall[i]-points[1][i])<=3)
                {
                    NSLog(@"accpeted");
                }
                
                if(norm(_GMVPointall[i] - points[1][i])>= 10 && norm(_GMVPointall[i] - points[1][i])<=20)
                {
                    points[1][i]=Point2f((points[1][i].x + _GMVPointall[i].x)/2.0,(points[1][i].y+ _GMVPointall[i].y)/2.0);
                    points[1][i] = _GMVPointall[i];
                    NSLog(@"wrong points, adjusting");
                }
                if(norm(_GMVPointall[i] - points[1][i])>20)
                {
                    points[1][i] = _GMVPointall[i];
                    NSLog(@"FATALE ERROR");
                }
            }
            if(!status[i])
                continue;
            circle(image, points[1][i], 5, cv::Scalar(0,255,0), -1, 8);
            
            //give out the center average point
            if(i%5==4){
                cv::Point2f showpoint;
                showpoint.x = (points[1][i].x+points[1][i-4].x+points[1][i-3].x+points[1][i-2].x+points[1][i-3].x)/5;
                showpoint.y = (points[1][i].y+points[1][i-4].y+points[1][i-3].y+points[1][i-2].y+points[1][i-3].y)/5;
                circle(image, showpoint, 5, cv::Scalar(0,0,255), -1, 8);
            }
        }
        
    }
    
    
    //for first init or give new results, put GMV results in points[1]
    if(_addRemovePt)
    {
        //test code -- upload points
        for(size_t i=0;i < _GMVPointall.size();i++){
            cv::vector<cv::Point2f> temp;
            temp.push_back(_touchPointall[i]);
            cornerSubPix(gray,temp, _winSize,cv::Size(-1,-1),_termcrit);
            points[1].push_back(temp[0]);
        }
        _addRemovePt = false;
    }
    
    newPoints = [NSArray arrayWithObjects:
                 [NSValue valueWithCGPoint:CGPointMake(points[1][0].x,points[1][0].y)],
                 [NSValue valueWithCGPoint:CGPointMake(points[1][1].x,points[1][1].y)],
                 [NSValue valueWithCGPoint:CGPointMake(points[1][2].x,points[1][2].y)],
                 [NSValue valueWithCGPoint:CGPointMake(points[1][3].x,points[1][3].y)],
                 nil];
    
    //swap currentpoint and previous points for next round
    std::swap(points[1], points[0]);
    cv::swap(gray_prev, gray);
    
    //temp: assume GMV gives me four points' results.
    
    //for(int j = 0;j<points[1].size();j++){
    //    CGPoint point_temp;
    //    point_temp.x = points[1][j].x;
    //    point_temp.y = points[1][j].y;
    //[newPoints addObject:point_temp];
    //}
    //newPoints = [NSArray arrayWithObjects:&(points[1][1].x,points[1][1].y) count:points[1].size()];
    return newPoints;
}

@end


