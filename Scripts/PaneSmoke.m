#import <AppKit/AppKit.h>
#import <PreferencePanes/PreferencePanes.h>

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        NSBundle *bundle = [NSBundle bundleWithPath:[NSString stringWithUTF8String:argv[1]]];
        NSError *error = nil;
        if (![bundle loadAndReturnError:&error]) {
            NSLog(@"Pane failed to load: %@", error);
            return 1;
        }
        Class type = bundle.principalClass;
        NSPreferencePane *pane = [[type alloc] initWithBundle:bundle];
        NSView *view = [pane loadMainView];
        if (![pane isKindOfClass:NSPreferencePane.class] || view.frame.size.width < 400 || view.frame.size.height < 400) { return 2; }
        printf("Preference pane loaded: %.0f × %.0f\n", view.frame.size.width, view.frame.size.height);
    }
    return 0;
}
