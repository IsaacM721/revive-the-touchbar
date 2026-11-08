#import <AppKit/AppKit.h>

// Private-but-long-stable AppKit entry points for showing a Touch Bar
// system-wide (this is what MTMR / Pock use).
@interface NSTouchBar (SystemModal)
+ (void)presentSystemModalTouchBar:(NSTouchBar *)touchBar
                         placement:(long long)placement
          systemTrayItemIdentifier:(nullable NSTouchBarItemIdentifier)identifier;
+ (void)dismissSystemModalTouchBar:(NSTouchBar *)touchBar;
+ (void)presentSystemModalFunctionBar:(NSTouchBar *)touchBar
             systemTrayItemIdentifier:(nullable NSTouchBarItemIdentifier)identifier;
+ (void)dismissSystemModalFunctionBar:(NSTouchBar *)touchBar;
@end

// Adds a button to the system Control Strip (the right-hand part of the native Touch Bar).
// DFRElementSetControlStripPresenceForIdentifier, which pins it there, is looked up at run time
// (see ControlStripItem.swift) so a macOS that drops it can't stop the app from launching.
@interface NSTouchBarItem (SystemTray)
+ (void)addSystemTrayItem:(NSTouchBarItem *)item;
+ (void)removeSystemTrayItem:(NSTouchBarItem *)item;
@end
