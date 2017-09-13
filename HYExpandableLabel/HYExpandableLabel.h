//
//  HYExpandableLabel.h
//  HYExpandableLabel
//
//  Created by zhuxuhong on 2017/9/7.
//  Copyright © 2017年 zhuxuhong. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef enum : NSUInteger {
	HYExpandableLabelActionClick,
	HYExpandableLabelActionDidCalculate
} HYExpandableLabelActionType;

@interface HYExpandableLabelContentView: UIView
@end



@interface HYExpandableLabel : UIView

@property(nonatomic,copy)NSAttributedString *attributedText;
@property(nonatomic)NSUInteger maximumLines;

@property(nonatomic,copy)void(^action)(HYExpandableLabelActionType type, id info);

@end
