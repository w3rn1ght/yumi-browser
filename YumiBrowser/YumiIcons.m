#import "YumiIcons.h"
#import <math.h>

@implementation YumiIcons

+ (UIImage *)draw:(void (^)(CGContextRef ctx, CGSize size))draw {
    CGSize size = CGSizeMake(26, 26);
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size];
    UIImage *img = [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        CGContextRef c = ctx.CGContext;
        CGContextSetLineWidth(c, 2.0);
        CGContextSetLineCap(c, kCGLineCapRound);
        CGContextSetLineJoin(c, kCGLineJoinRound);
        CGContextSetStrokeColorWithColor(c, [UIColor blackColor].CGColor);
        CGContextSetFillColorWithColor(c, [UIColor blackColor].CGColor);
        if (draw) draw(c, size);
    }];
    return [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

+ (UIImage *)chevronLeft {
    return [self draw:^(CGContextRef c, CGSize s) {
        CGContextMoveToPoint(c, 16, 5);
        CGContextAddLineToPoint(c, 9, 13);
        CGContextAddLineToPoint(c, 16, 21);
        CGContextStrokePath(c);
    }];
}

+ (UIImage *)chevronRight {
    return [self draw:^(CGContextRef c, CGSize s) {
        CGContextMoveToPoint(c, 10, 5);
        CGContextAddLineToPoint(c, 17, 13);
        CGContextAddLineToPoint(c, 10, 21);
        CGContextStrokePath(c);
    }];
}

+ (UIImage *)reload {
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(26, 26)];
    UIImage *img = [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        NSDictionary *attrs = @{
            NSFontAttributeName: [UIFont systemFontOfSize:21 weight:UIFontWeightRegular],
            NSForegroundColorAttributeName: [UIColor blackColor]
        };
        NSString *glyph = @"↻";
        CGSize textSize = [glyph sizeWithAttributes:attrs];
        [glyph drawAtPoint:CGPointMake((26.0 - textSize.width) / 2.0,
                                       (26.0 - textSize.height) / 2.0 + 0.5)
            withAttributes:attrs];
    }];
    return [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

+ (UIImage *)stop {
    return [self draw:^(CGContextRef c, CGSize s) {
        CGContextSetLineWidth(c, 2.3);
        CGContextMoveToPoint(c, 7.5, 7.5);
        CGContextAddLineToPoint(c, 18.5, 18.5);
        CGContextStrokePath(c);
        CGContextMoveToPoint(c, 18.5, 7.5);
        CGContextAddLineToPoint(c, 7.5, 18.5);
        CGContextStrokePath(c);
    }];
}

+ (UIImage *)streams {
    return [self draw:^(CGContextRef c, CGSize s) {
        UIBezierPath *rect = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(3.5, 5, 19, 16)
                                                           cornerRadius:4.0];
        CGContextAddPath(c, rect.CGPath);
        CGContextStrokePath(c);
        CGContextMoveToPoint(c, 11, 9.5);
        CGContextAddLineToPoint(c, 18.5, 13);
        CGContextAddLineToPoint(c, 11, 16.5);
        CGContextClosePath(c);
        CGContextFillPath(c);
    }];
}

+ (UIImage *)tabs {
    return [self draw:^(CGContextRef c, CGSize s) {
        UIBezierPath *back = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(4, 4, 12, 15) cornerRadius:2.5];
        CGContextAddPath(c, back.CGPath);
        CGContextStrokePath(c);
        UIBezierPath *front = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(10, 7, 12, 15) cornerRadius:2.5];
        CGContextSetFillColorWithColor(c, [UIColor whiteColor].CGColor);
        CGContextAddPath(c, front.CGPath);
        CGContextFillPath(c);
    }];
}

+ (UIImage *)home {
    return [self draw:^(CGContextRef c, CGSize s) {
        CGContextMoveToPoint(c, 4, 13);
        CGContextAddLineToPoint(c, 13, 5);
        CGContextAddLineToPoint(c, 22, 13);
        CGContextStrokePath(c);
        CGContextMoveToPoint(c, 7, 12.5);
        CGContextAddLineToPoint(c, 7, 21);
        CGContextAddLineToPoint(c, 19, 21);
        CGContextAddLineToPoint(c, 19, 12.5);
        CGContextStrokePath(c);
    }];
}

+ (UIImage *)ellipsis {
    return [self draw:^(CGContextRef c, CGSize s) {
        for (int i = 0; i < 3; i++) {
            CGContextFillEllipseInRect(c, CGRectMake(5 + i * 6.5, 11.5, 4, 4));
        }
    }];
}

+ (UIImage *)play {
    return [self draw:^(CGContextRef c, CGSize s) {
        CGContextMoveToPoint(c, 9, 5.5);
        CGContextAddLineToPoint(c, 21, 13);
        CGContextAddLineToPoint(c, 9, 20.5);
        CGContextClosePath(c);
        CGContextFillPath(c);
    }];
}

+ (UIImage *)close {
    return [self draw:^(CGContextRef c, CGSize s) {
        CGContextMoveToPoint(c, 8, 8);
        CGContextAddLineToPoint(c, 18, 18);
        CGContextStrokePath(c);
        CGContextMoveToPoint(c, 18, 8);
        CGContextAddLineToPoint(c, 8, 18);
        CGContextStrokePath(c);
    }];
}

+ (UIImage *)desktop {
    return [self draw:^(CGContextRef c, CGSize s) {
        UIBezierPath *p = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(3.5, 5, 19, 13) cornerRadius:2];
        CGContextAddPath(c, p.CGPath);
        CGContextStrokePath(c);
        CGContextMoveToPoint(c, 9, 21);
        CGContextAddLineToPoint(c, 17, 21);
        CGContextStrokePath(c);
        CGContextMoveToPoint(c, 13, 18);
        CGContextAddLineToPoint(c, 13, 21);
        CGContextStrokePath(c);
    }];
}

+ (UIImage *)shield {
    return [self draw:^(CGContextRef c, CGSize s) {
        CGContextMoveToPoint(c, 13, 3.5);
        CGContextAddLineToPoint(c, 21, 6.5);
        CGContextAddLineToPoint(c, 21, 13);
        CGContextAddCurveToPoint(c, 21, 18, 17.5, 20.5, 13, 22.5);
        CGContextAddCurveToPoint(c, 8.5, 20.5, 5, 18, 5, 13);
        CGContextAddLineToPoint(c, 5, 6.5);
        CGContextClosePath(c);
        CGContextStrokePath(c);
    }];
}

@end
