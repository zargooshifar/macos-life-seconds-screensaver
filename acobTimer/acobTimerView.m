//
//  acobTimerView.m
//  acobTimer
//
//  Created by Yaghoub ZargooshiFar on 21.07.23.
//

#import "acobTimerView.h"

static NSString* const kWebscreenModuleName = @"ir.zarg.acobTimer";


@implementation acobTimerView
{
  WKWebView* _webView;
  BOOL _animationStarted;
}

- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview
{
  NSBundle* ownBundle = [NSBundle bundleForClass:[acobTimerView class]];
  return [self initWithFrame:frame
    isPreview:isPreview
    withDefaults:[ScreenSaverDefaults defaultsForModuleWithName:kWebscreenModuleName]
    withInfoDictionary:[ownBundle infoDictionary]];
}

- (instancetype)initWithFrame:(NSRect)frame
    isPreview:(BOOL)isPreview
    withDefaults:(NSUserDefaults*)defaults
    withInfoDictionary:(NSDictionary*)plist
{
  self = [super initWithFrame:frame isPreview:isPreview];
  if ( ! self) {
    return self;
  }
    
  self.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  self.autoresizesSubviews = NO;
  self.wantsLayer = YES;

  self.bounds = frame;
  self.frame = frame;

  WKWebViewConfiguration* conf = [[WKWebViewConfiguration alloc] init];
  conf.suppressesIncrementalRendering = NO;
  conf.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeAll;

  _webView = [[WKWebView alloc] initWithFrame:frame configuration:conf];
  _webView.navigationDelegate = self;
  _webView.alphaValue = 0.0;

  [self addSubview:_webView];
  [self resizeSubviewsWithOldSize:NSZeroSize];
  return self;
}

#pragma mark - screensaver implementation

- (void)startAnimation
{
  [super startAnimation];
  if (_animationStarted) {
    return;
  }
  _animationStarted = YES;

  self.layer.backgroundColor = CGColorGetConstantColor(kCGColorBlack);
  _webView.alphaValue = 0.0;
    NSURL *url = [[NSBundle bundleForClass:[self class]] URLForResource:@"index" withExtension:@"html"  ];
  [_webView loadRequest:[NSURLRequest requestWithURL:url]];

}

- (void)stopAnimation
{
  [super stopAnimation];
  _animationStarted = NO;
  _webView.animator.alphaValue = 0.0;
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldSize
{
  CGRect bounds = NSRectToCGRect(self.bounds);
  CGAffineTransform transform = CGAffineTransformIdentity;
  CGRect childBounds = CGRectApplyAffineTransform(bounds, transform);

  _webView.frame = childBounds;
}


#pragma mark - navigation delegate

- (void) webView:(WKWebView*)webView didFinishNavigation:(null_unspecified WKNavigation *)navigation
{
  if (_webView.alphaValue < 1.0) {
    WKWebView* animator = [_webView animator];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1000 * NSEC_PER_MSEC),
                   dispatch_get_main_queue(),
                   ^(void) {
      animator.alphaValue = 1.0;
    });
  }
}

#pragma mark - WSKit implementation
- (void)injectWSKitScriptInUserContentController:
    (WKUserContentController*)userContentController
{
  NSBundle* bundle = [NSBundle bundleForClass:[acobTimerView class]];
  NSString* scriptLocation = [bundle pathForResource:@"webscreen" ofType:@"js"];
  NSString* scriptSource = [NSString stringWithContentsOfFile:scriptLocation
      encoding:NSUTF8StringEncoding error:nil];
  WKUserScript* userScript = [[WKUserScript alloc]
      initWithSource:scriptSource
      injectionTime:WKUserScriptInjectionTimeAtDocumentStart
      forMainFrameOnly:YES];

  [userContentController addUserScript:userScript];
}

- (NSDictionary*)configForWSKit
{
  NSArray* screens = [NSScreen screens];
  NSScreen* currentScreen = [NSScreen mainScreen];
  return @{
    @"display": [NSNumber numberWithUnsignedInteger:
        [screens indexOfObject:currentScreen] + 1],
    @"totalDisplays": [NSNumber numberWithUnsignedInteger:[screens count]],
  };
}

- (void)userContentController:(WKUserContentController*)userContentController
    didReceiveScriptMessage:(WKScriptMessage*)message
{
  // apparently message.name is the name passed to the registration function
  // and message.body is the argument to the postMessage function in JS
  // counterintuitive innit
  NSString* messageName = message.body;

  if ([messageName isEqualToString:@"obtainconfiguration"]) {
    NSError *err;
    NSDictionary* config = [self configForWSKit];
    NSData *json = [NSJSONSerialization dataWithJSONObject:config
        options:0 error:&err];
    if ( ! json) {
      NSLog(@"[Webscreen] WSKit configuration: error: %@",
          err.localizedDescription);
      return;
    }

    NSString* jsonStr = [[NSString alloc]
      initWithData:json encoding:NSUTF8StringEncoding];
    NSString* invocation = [NSString stringWithFormat:
      @"WSKit.dispatchEvent('configure', %@);", jsonStr];
    [_webView evaluateJavaScript:invocation completionHandler:nil];
  }
}

@end
