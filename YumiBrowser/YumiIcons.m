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
    return [self draw:^(CGContextRef c, CGSize s) {
        CGFloat cx = 13.0, cy = 13.0, radius = 7.4;
        CGFloat start = (CGFloat)(-M_PI * 0.30);
        CGFloat end = (CGFloat)(M_PI * 1.36);
        NSInteger steps = 48;

        CGContextSetLineWidth(c, 2.2);
        for (NSInteger i = 0; i <= steps; i++) {
            CGFloat a = start + (end - start) * ((CGFloat)i / (CGFloat)steps);
            CGFloat x = cx + radius * cosf(a);
            CGFloat y = cy + radius * sinf(a);
            if (i == 0) CGContextMoveToPoint(c, x, y);
            else CGContextAddLineToPoint(c, x, y);
        }
        CGContextStrokePath(c);

        // Стрелка на конце дуги.
        CGFloat sx = cx + radius * cosf(start);
        CGFloat sy = cy + radius * sinf(start);
        CGFloat tx = -sinf(start), ty = cosf(start);
        CGFloat px = -ty, py = tx;

        CGContextMoveToPoint(c, sx + tx * 3.4, sy + ty * 3.4);
        CGContextAddLineToPoint(c, sx + px * 3.0, sy + py * 3.0);
        CGContextAddLineToPoint(c, sx - px * 3.0, sy - py * 3.0);
        CGContextClosePath(c);
        CGContextFillPath(c);
    }];
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

+ (UIImage *)download {
    return [self draw:^(CGContextRef c, CGSize s) {
        // Стрелка вниз.
        CGContextMoveToPoint(c, 13, 4.5);
        CGContextAddLineToPoint(c, 13, 16.5);
        CGContextStrokePath(c);
        CGContextMoveToPoint(c, 8, 11.5);
        CGContextAddLineToPoint(c, 13, 16.5);
        CGContextAddLineToPoint(c, 18, 11.5);
        CGContextStrokePath(c);
        // Лоток.
        CGContextMoveToPoint(c, 6, 18.5);
        CGContextAddLineToPoint(c, 6, 21);
        CGContextAddLineToPoint(c, 20, 21);
        CGContextAddLineToPoint(c, 20, 18.5);
        CGContextStrokePath(c);
    }];
}

@end
