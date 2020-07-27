#import <UIKit/UIKit.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>

#define WNDistortionView_X_DIVISION (8)
#define WNDistortionView_Y_DIVISION (8)

@interface WNDistortionView : UIView
{
    UIImage *image;
	GLint backingWidth;
	GLint backingHeight;

	EAGLContext *eaglContext;

	GLuint viewRenderbuffer;
    GLuint viewFramebuffer;

	GLuint imageTexture;
    
    CGSize srcImageSize;
    CGSize textureSize;

    GLuint shapeBuffers[2];
    
    CGPoint centerPoint;
    CGFloat theta;
    CGFloat radius;

    GLfloat spriteVertices[(WNDistortionView_X_DIVISION+1)*(WNDistortionView_Y_DIVISION+1)*2];
    GLfloat spriteTexcoords[(WNDistortionView_X_DIVISION+1)*(WNDistortionView_Y_DIVISION+1)*2];
    GLushort indices[WNDistortionView_X_DIVISION*WNDistortionView_Y_DIVISION*6];
}

- (id)initWithFrame:(CGRect)aRect image:(UIImage *)anImage;
- (void)drawView;

@property (nonatomic, assign) CGPoint centerPoint;
@property (nonatomic, assign) CGFloat theta;

@end
