#import "WNDistortionView.h"

@interface WNDistortionView ()
- (BOOL)createFramebuffer;
- (void)destroyFramebuffer;
- (BOOL)createTexture;
- (void)destroyTexture;
- (void)setupView;
- (void)drawView;
- (void)setCenterPoint:(CGPoint)point;
@end

inline static float linearInterpolation(float v1, float v2, float theta)
{
    if(theta < 0.0f)
        theta = 0.0f;
    else if(theta > 1.0f)
        theta = 1.0f;

    return v1 * (1.0f-theta) + v2 * theta;
}

@implementation WNDistortionView

@synthesize centerPoint;
@synthesize theta;

+ (Class)layerClass
{
	return [CAEAGLLayer class];
}

- (void)dealloc
{
    glDeleteBuffers(2, shapeBuffers);
    [self destroyTexture];
    [self destroyFramebuffer];

	if([EAGLContext currentContext] == eaglContext) {
		[EAGLContext setCurrentContext:nil];
	}
	
	eaglContext = nil;


}

- (id)commonInit
{
    CAEAGLLayer *eaglLayer = (CAEAGLLayer*) self.layer;
    self.backgroundColor = [UIColor clearColor];
    self.opaque = NO;
    eaglLayer.opaque = NO;
    eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithBool:FALSE], kEAGLDrawablePropertyRetainedBacking,
                                    kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat,
                                    nil];

    eaglContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
    if(!eaglContext || ![EAGLContext setCurrentContext:eaglContext] || ![self createFramebuffer]) {
        return nil;
    }

    [self createTexture];
    [self setupView];
    [self setCenterPoint:CGPointMake(backingWidth/2, backingHeight/2)];
//    animationInterval = 1.0 / 60.0;
    [self drawView];
    
    return self;
}

- (id)initWithFrame:(CGRect)aRect image:(UIImage *)anImage
{
	if((self = [super initWithFrame:aRect])) {
        image = anImage;
        self = [self commonInit];
    }
    
    return self;
}

- (id)initWithCoder:(NSCoder*)coder
{
	if((self = [super initWithCoder:coder])) {
        self = [self commonInit];
	}
	
	return self;
}


- (void)layoutSubviews
{
//	[EAGLContext setCurrentContext:context];
//	[self destroyFramebuffer];
//	[self createFramebuffer];
//	[self drawView];
}

- (BOOL)createFramebuffer
{
	glGenFramebuffersOES(1, &viewFramebuffer);
	glGenRenderbuffersOES(1, &viewRenderbuffer);
	
	glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
	glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
	[eaglContext renderbufferStorage:GL_RENDERBUFFER_OES fromDrawable:(id<EAGLDrawable>)self.layer];
	glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_RENDERBUFFER_OES, viewRenderbuffer);
	
	glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, &backingWidth);
	glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, &backingHeight);
	
	if(glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES) != GL_FRAMEBUFFER_COMPLETE_OES) {
		NSLog(@"failed to make complete framebuffer object %x", glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES));
		return NO;
	}
	
	return YES;
}


- (void)destroyFramebuffer
{
	glDeleteFramebuffersOES(1, &viewFramebuffer);
	viewFramebuffer = 0;
	glDeleteRenderbuffersOES(1, &viewRenderbuffer);
	viewRenderbuffer = 0;
}

- (CGFloat)ceilPowerOfTwo:(CGFloat)n
{
    CGFloat retVal = 1;
    
    while(1) {
        if(n == retVal || n < retVal) {
            break;
        }
        
        retVal *= 2;
    }
    
    return retVal;
}

- (BOOL)createTexture
{
	CGImageRef spriteImage;
	CGContextRef spriteContext;
	GLubyte *spriteData;
	size_t	width, height;
    
	spriteImage = image.CGImage;
	width = CGImageGetWidth(spriteImage);
	height = CGImageGetHeight(spriteImage);
    
    srcImageSize.width = width;
    srcImageSize.height = height;

    textureSize.width = [self ceilPowerOfTwo:width];
    textureSize.height = [self ceilPowerOfTwo:height];

	if(spriteImage) {
		spriteData = (GLubyte *) malloc((size_t)textureSize.width * (size_t)textureSize.height * 4);
		spriteContext = CGBitmapContextCreate(spriteData, (size_t)textureSize.width, (size_t)textureSize.height, 8, (size_t)textureSize.width * 4, CGImageGetColorSpace(spriteImage), kCGImageAlphaPremultipliedLast);
		CGContextDrawImage(spriteContext, CGRectMake(0.0, (size_t)textureSize.height - (CGFloat)height, (CGFloat)width, (CGFloat)height), spriteImage);
		CGContextRelease(spriteContext);
		
		glGenTextures(1, &imageTexture);
		glBindTexture(GL_TEXTURE_2D, imageTexture);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (GLsizei)textureSize.width, (GLsizei)textureSize.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, spriteData);
		free(spriteData);
		
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		
		glEnable(GL_TEXTURE_2D);
		// Set a blending function to use
		//glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
		// Enable blending
		//glEnable(GL_BLEND);
		//glDisable(GL_BLEND);
	} else {
        return NO;
    }
    
    return YES;
}

- (void)destroyTexture
{
    glDeleteTextures(1, &imageTexture);
    imageTexture = 0;
}

#define BUFFER_OFFSET(bytes) ((GLintptr)((GLubyte *)NULL + (bytes)))

- (void)setupView
{
	glViewport(0, 0, backingWidth, backingHeight);
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	glOrthof(0, backingWidth, backingHeight, 0, -1.0f, 1.0f);
	glMatrixMode(GL_MODELVIEW);
	
	glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
	
    CGFloat u = srcImageSize.width / textureSize.width;
    CGFloat v = srcImageSize.height / textureSize.height;
    float *vertexp = spriteVertices;
    float *texp = spriteTexcoords;
    float dvx = (float)backingWidth / WNDistortionView_X_DIVISION;
    float dvy = (float)backingHeight / WNDistortionView_Y_DIVISION;
    float du = u / WNDistortionView_X_DIVISION;
    float dv = v / WNDistortionView_X_DIVISION;
    for(int y = 0; y <= WNDistortionView_Y_DIVISION; y++) {
        for(int x = 0; x <= WNDistortionView_X_DIVISION; x++) {
            *vertexp = x * dvx;
            vertexp++;
            *vertexp = y * dvy;
            vertexp++;

            *texp = x * du;
            texp++;
            *texp = y * dv;
            texp++;
        }
    }

    GLushort idx[2];
    GLushort *idxp = indices;
    for(int y = 0; y < WNDistortionView_Y_DIVISION; y++) {
        for(int x = 0; x < WNDistortionView_X_DIVISION; x++) {
            idx[0] = x + y * (WNDistortionView_X_DIVISION + 1);
            idx[1] = x + (y + 1) * (WNDistortionView_X_DIVISION + 1);
            *idxp++= idx[0];
            *idxp++= idx[0]+1;
            *idxp++= idx[1];

            *idxp++= idx[0]+1;
            *idxp++= idx[1];
            *idxp++= idx[1]+1;
        }
    }
    
    glGenBuffers(2, shapeBuffers);
    glBindBuffer(GL_ARRAY_BUFFER, shapeBuffers[0]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(spriteVertices) + sizeof(spriteTexcoords), NULL, GL_DYNAMIC_DRAW);
    glBufferSubData(GL_ARRAY_BUFFER, BUFFER_OFFSET(0), sizeof(spriteVertices), spriteVertices);
    glBufferSubData(GL_ARRAY_BUFFER, BUFFER_OFFSET(sizeof(spriteVertices)), sizeof(spriteTexcoords), spriteTexcoords);
    
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, shapeBuffers[1]);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW);
}

- (void)drawView
{
	// Make sure that you are drawing to the current context
	[EAGLContext setCurrentContext:eaglContext];
	
	glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
	
	glClear(GL_COLOR_BUFFER_BIT);

    glEnableClientState(GL_VERTEX_ARRAY);
    glEnableClientState(GL_TEXTURE_COORD_ARRAY);
    
    glBindBuffer(GL_ARRAY_BUFFER, shapeBuffers[0]);
    glVertexPointer(2, GL_FLOAT, 0, (GLvoid *)BUFFER_OFFSET(0));
    glTexCoordPointer(2, GL_FLOAT, 0, (GLvoid *)BUFFER_OFFSET(sizeof(spriteVertices)));

    float *vertexp = spriteVertices;
    float dvx = (float)backingWidth / WNDistortionView_X_DIVISION;
    float dvy = (float)backingHeight / WNDistortionView_Y_DIVISION;
    for(int y = 0; y <= WNDistortionView_Y_DIVISION; y++) {
        for(int x = 0; x <= WNDistortionView_X_DIVISION; x++) {
            float px = x * dvx;
            float py = y * dvy;
            float distance = sqrtf(powf((px-centerPoint.x), 2.0f) + powf(py-centerPoint.y, 2.0f));
            
            float thetaAdjust = 1.0f-/*(distance/radius)*/powf((distance/radius), 1.0f/0.8f);
            float adjustRange = 3.0f;
            thetaAdjust = (thetaAdjust * adjustRange) - adjustRange/2.0f;
            //printf("%f\n", thetaAdjust);
//            float gamma = 1.0f + thetaAdjust * 10.0f;
//            float theta2 = powf(theta, 1.0f/gamma);
            //float theta2 = cos((theta + thetaAdjust)/2.0f);
            float min,max;
            if(thetaAdjust < 0) {
                min = thetaAdjust;
                max = 1.0f;
            } else {
                min = 0.0f;
                max = 1.0f + thetaAdjust;
            }
            
            float theta2 = linearInterpolation(min, max, /*powf(theta, 1.0f/0.8f)*/theta);

            *vertexp = linearInterpolation(px, centerPoint.x, theta2);
            vertexp++;
            *vertexp = linearInterpolation(py, centerPoint.y, theta2);
            vertexp++;
        }
    }

    glBufferSubData(GL_ARRAY_BUFFER, BUFFER_OFFSET(0), sizeof(spriteVertices), spriteVertices);

    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, shapeBuffers[1]);
    glEnable(GL_TEXTURE_2D);
    glDrawElements(GL_TRIANGLES, sizeof(indices)/sizeof(GLushort), GL_UNSIGNED_SHORT, (void*)0);
    glDisable(GL_TEXTURE_2D);
    
    glDisableClientState(GL_VERTEX_ARRAY);
    glDisableClientState(GL_TEXTURE_COORD_ARRAY);
    
	glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
	[eaglContext presentRenderbuffer:GL_RENDERBUFFER_OES];
}

- (void)setCenterPoint:(CGPoint)point
{
    centerPoint = point;
    
    CGFloat r = 0;
    CGFloat d;
    CGFloat x, y;
    
    x = 0;
    y = 0;
    d = sqrtf(powf(x-centerPoint.x, 2.0f) + powf(y-centerPoint.y, 2.0f));
    if(d > r) r = d;

    x = backingWidth;
    y = 0;
    d = sqrtf(powf(x-centerPoint.x, 2.0f) + powf(y-centerPoint.y, 2.0f));
    if(d > r) r = d;

    x = 0;
    y = backingHeight;
    d = sqrtf(powf(x-centerPoint.x, 2.0f) + powf(y-centerPoint.y, 2.0f));
    if(d > r) r = d;

    x = backingWidth;
    y = backingHeight;
    d = sqrtf(powf(x-centerPoint.x, 2.0f) + powf(y-centerPoint.y, 2.0f));
    if(d > r) r = d;
    
    radius = r;
    
    [self drawView];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    [self setCenterPoint:[touch locationInView:self]];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    [self setCenterPoint:[touch locationInView:self]];
}

@end
