//
//  HYExpandableLabel.m
//  HYExpandableLabel
//
//  Created by zhuxuhong on 2017/9/7.
//  Copyright © 2017年 zhuxuhong. All rights reserved.
//

#import "HYExpandableLabel.h"
#import <CoreText/CoreText.h>

#pragma mark - HYExpandableLabelContentView
@interface HYExpandableLabelContentView()

@property(copy, nonatomic)NSAttributedString *attributedText;

@end

@implementation HYExpandableLabelContentView

-(void)drawRect:(CGRect)rect{
	[super drawRect:rect];
	
	if (!_attributedText) {
		return;
	}
	[self drawText];
}

#pragma mark - Setters Method
-(void)setAttributedText:(NSAttributedString *)attributedText{
	_attributedText = attributedText;
	
	[self setNeedsDisplay];
}

-(void)drawText{
	CGContextRef context = UIGraphicsGetCurrentContext();
	CGContextSetTextMatrix(context, CGAffineTransformIdentity);
	CGContextTranslateCTM(context, 0, self.bounds.size.height);
	CGContextScaleCTM(context, 1.0, -1.0);
	
	CTFramesetterRef setter = CTFramesetterCreateWithAttributedString((CFAttributedStringRef)_attributedText);
	
	CTFrameRef ctFrame = CTFramesetterCreateFrame(setter, CFRangeMake(0, _attributedText.length), CGPathCreateWithRect(self.bounds, nil), NULL);
	
	CTFrameDraw(ctFrame, context);
}

@end


#pragma mark - HYExpandableLabel

typedef void(^HYAttributedTextDrawCompletion)(CGFloat height, NSAttributedString *drawAttributedText);

@interface HYExpandableLabel()

#pragma mark - Private Properties
@property(nonatomic,copy)NSAttributedString *clickAttributedText;
@property(nonatomic,copy)HYExpandableLabelContentView *contentView;
@property(nonatomic)BOOL isExpanded; 
@property(nonatomic)CGRect clickArea;

@end

@implementation HYExpandableLabel
{
	CGFloat _lineHeightErrorDimension; //误差值
}

#pragma mark - Initial Method
-(instancetype)initWithFrame:(CGRect)frame{
	if (self = [super initWithFrame:frame]) 
	{
		[self initData];
		
		[self setupUI];
	}
	return self;
}

-(instancetype)initWithCoder:(NSCoder *)aDecoder{
	if (self = [super initWithCoder:aDecoder]) 
	{
		[self initData];
		
		[self setupUI];
	}
	return self;
}

-(void)setupUI{
	self.backgroundColor = [UIColor clearColor];
	
	[self addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(actionGestureTapped:)]];
}

-(void)initData{
	_lineHeightErrorDimension = 0.5;
	_maximumLines = 3;
	
	[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(actionNotificationReceived:) name:UIDeviceOrientationDidChangeNotification object:nil];
}


#pragma mark - Lifecycle Method
-(void)drawRect:(CGRect)rect{
	[super drawRect:rect];
	
	if (!_attributedText) {
		return;
	}
	
	[self drawTextWithCompletion:^(CGFloat height, NSAttributedString *drawAttributedText) {
		[self addSubview:self.contentView];
		self.contentView.frame = CGRectMake(0, 0, self.bounds.size.width, height);
		self.contentView.attributedText = drawAttributedText;
		
		_action ? _action(HYExpandableLabelActionDidCalculate, @(height)) : nil;
	}];
}

-(void)dealloc{
	[NSNotificationCenter.defaultCenter removeObserver:self];
}

#pragma mark - Setters Method
-(void)setAttributedText:(NSAttributedString *)attributedText{
	_attributedText = attributedText;
	
	[self setNeedsDisplay];
}

-(void)setMaximumLines:(NSUInteger)maximumLines{
	_maximumLines = maximumLines;
	
	[self setNeedsDisplay];
}

-(void)setIsExpanded:(BOOL)isExpanded{
	_isExpanded = isExpanded;
	
	[self setNeedsDisplay];
}

#pragma mark - Public Method


#pragma mark - Action Method
-(void)actionNotificationReceived: (NSNotification*)sender{
	if ([sender.name isEqualToString:UIDeviceOrientationDidChangeNotification]) {
		self.isExpanded = _isExpanded;
	}
}

-(void)actionGestureTapped: (UITapGestureRecognizer*)sender{
	if (CGRectContainsPoint(_clickArea, [sender locationInView:self])) {
		self.isExpanded = !_isExpanded;
		_action ? _action(HYExpandableLabelActionClick, nil) : nil;
	}
}

#pragma mark - Private Method
-(void)drawTextWithCompletion: (HYAttributedTextDrawCompletion)completion{
	_isExpanded
	? [self calculateFullTextWithCompletion:completion] 
	: [self calculatePartialTextWithCompletion:completion];
}

-(void)calculateFullTextWithCompletion: (HYAttributedTextDrawCompletion)completion{
	
	CGPathRef path = CGPathCreateWithRect(CGRectMake(0, 0, self.bounds.size.width, UIScreen.mainScreen.bounds.size.height), nil);
	
	NSMutableAttributedString *drawAttributedText = [[NSMutableAttributedString alloc] initWithAttributedString:_attributedText];
	[drawAttributedText appendAttributedString:self.clickAttributedText];
	
	// CTFrameRef
	CTFramesetterRef setter = CTFramesetterCreateWithAttributedString((CFAttributedStringRef)drawAttributedText);
	CTFrameRef ctFrame = CTFramesetterCreateFrame(setter, CFRangeMake(0, drawAttributedText.length), path, NULL);
	
	// CTLines
	NSArray *lines = (NSArray*)CTFrameGetLines(ctFrame);
	
	CGFloat totalHeight = 0;
	
	for (int i=0; i<lines.count; i++) {
		CTLineRef line = (__bridge CTLineRef)lines[i];
		totalHeight += [self heightForCTLine:line];
		
		if (i == lines.count - 1) {
			CTLineRef moreLine = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)self.clickAttributedText);
			
			NSArray *runs = (NSArray*)CTLineGetGlyphRuns(line);
			CGFloat w = 0;
			for (int i=0; i<runs.count; i++) {
				if (i == runs.count - 1) {
					break;
				}
				CTRunRef run = (__bridge CTRunRef)runs[i];
				w += CTRunGetTypographicBounds(run, CFRangeMake(0, 0), NULL, NULL, NULL);
			}
			
			CGSize moreSize = CTLineGetBoundsWithOptions(moreLine, 0).size;
			CGFloat h = moreSize.height + lines.count * _lineHeightErrorDimension;
			self.clickArea = CGRectMake(w, totalHeight - h, moreSize.width, h);
		}
	}
	
	completion(totalHeight, drawAttributedText);
}

-(void)calculatePartialTextWithCompletion: (HYAttributedTextDrawCompletion)completion{	
	CGPathRef path = CGPathCreateWithRect(CGRectMake(0, 0, self.bounds.size.width, UIScreen.mainScreen.bounds.size.height), nil);
	
	// CTFrameRef
	CTFramesetterRef setter = CTFramesetterCreateWithAttributedString((CFAttributedStringRef)_attributedText);
	CTFrameRef ctFrame = CTFramesetterCreateFrame(setter, CFRangeMake(0, _attributedText.length), path, NULL);
	
	// CTLines
	NSArray *lines = (NSArray*)CTFrameGetLines(ctFrame);
	
	// CTLine Origins
	CGPoint origins[lines.count];
	CTFrameGetLineOrigins(ctFrame, CFRangeMake(0, 0), origins);
	CGFloat totalHeight = 0;
	
	NSMutableAttributedString *drawAttributedText = [NSMutableAttributedString new];
	
	for (int i=0; i<lines.count; i++) {
		if (lines.count > _maximumLines && i == _maximumLines) {
			break;
		}
		CTLineRef line = (__bridge CTLineRef)lines[i];
		
		CGPoint lineOrigin = origins[i];
		
		CFRange range = CTLineGetStringRange(line);
		NSAttributedString *subAttr = [_attributedText attributedSubstringFromRange:NSMakeRange(range.location, range.length)];
		if (lines.count > _maximumLines && i == _maximumLines - 1) {
			NSMutableAttributedString *drawAttr = [[NSMutableAttributedString alloc] initWithAttributedString:subAttr];
			
			for (int j=0; j<drawAttr.length; j++) {
				NSMutableAttributedString *lastLineAttr = [[NSMutableAttributedString alloc] initWithAttributedString:[drawAttr attributedSubstringFromRange:NSMakeRange(0, drawAttr.length-j)]];
				
				[lastLineAttr appendAttributedString:self.clickAttributedText];
				
				NSInteger number = [self numberOfLinesForAttributtedText:lastLineAttr withOriginPoint:lineOrigin];
				
				if (number == 1) {
					[drawAttributedText appendAttributedString:lastLineAttr];
					
					CTLineRef moreLine = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)self.clickAttributedText);
					CGSize moreSize = CTLineGetBoundsWithOptions(moreLine, 0).size;
					
					self.clickArea = CGRectMake(self.bounds.size.width-moreSize.width, totalHeight, moreSize.width, moreSize.height);
					
					totalHeight += [self heightForCTLine:line];
					break;
				}
			}
		}
		else{
			[drawAttributedText appendAttributedString:subAttr];
			
			totalHeight += [self heightForCTLine:line];
		}
	}
	
	completion(totalHeight, drawAttributedText);
}

-(CGFloat)heightForCTLine: (CTLineRef)line{
	CGFloat h = 0;
	
	NSArray *runs = (NSArray*)CTLineGetGlyphRuns(line);
	for (int i=0; i<runs.count; i++) {
		CTRunRef run = (__bridge CTRunRef)runs[i];
		CGFloat ascent;
		CGFloat descent;
		CGFloat leading;
		CTRunGetTypographicBounds(run, CFRangeMake(0, 0), &ascent, &descent, &leading);
		h = MAX(h, ascent + descent + leading);
	}
	return h + _lineHeightErrorDimension;
}

-(NSInteger)numberOfLinesForAttributtedText: (NSAttributedString*)text 
							withOriginPoint: (CGPoint)origin{
	CGPathRef path = CGPathCreateWithRect(CGRectMake(0, 0, self.bounds.size.width, UIScreen.mainScreen.bounds.size.height), nil);
	
	CTFramesetterRef setter = CTFramesetterCreateWithAttributedString((CFAttributedStringRef)text);
	CTFrameRef ctFrame = CTFramesetterCreateFrame(setter, CFRangeMake(0, text.length), path, nil);
	NSArray *lines = (NSArray*)CTFrameGetLines(ctFrame);
	return lines.count;
}


#pragma mark - Getters Method
-(NSAttributedString *)clickAttributedText{
	return _isExpanded 
	? [[NSAttributedString alloc] initWithString:@"收起" attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:14], NSForegroundColorAttributeName: [UIColor orangeColor]}] 
	: [[NSAttributedString alloc] initWithString:@"...更多" attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:14], NSForegroundColorAttributeName: [UIColor orangeColor]}]; 
}

-(HYExpandableLabelContentView *)contentView{
	if (!_contentView) {
		HYExpandableLabelContentView *v = [HYExpandableLabelContentView new];
		v.backgroundColor = [UIColor clearColor];
		
		_contentView = v;
	}
	return _contentView;
}
@end
