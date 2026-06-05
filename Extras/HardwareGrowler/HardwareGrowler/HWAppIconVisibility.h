#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>

typedef enum : NSInteger {
	kShowIconInMenu = 0,
	kShowIconInDock = 1,
	kShowIconInBoth = 2,
	kDontShowIcon = 3
} HWGrowlIconState;

/* Centralizes the Dock/menu-bar visibility rules so Preferences can apply the
   choice immediately and tests can verify the hidden state without AppKit UI. */
static inline BOOL HWGIconVisibilityShowsMenuBarIcon(HWGrowlIconState visibility)
{
	return (visibility == kShowIconInMenu || visibility == kShowIconInBoth);
}

static inline BOOL HWGIconVisibilityShowsDockIcon(HWGrowlIconState visibility)
{
	return (visibility == kShowIconInDock || visibility == kShowIconInBoth);
}

static inline NSApplicationActivationPolicy HWGIconVisibilityActivationPolicy(HWGrowlIconState visibility)
{
	return HWGIconVisibilityShowsDockIcon(visibility) ? NSApplicationActivationPolicyRegular : NSApplicationActivationPolicyAccessory;
}

static inline BOOL HWGIconVisibilityNeedsStatusItem(HWGrowlIconState visibility, BOOL hasStatusItem)
{
	return HWGIconVisibilityShowsMenuBarIcon(visibility) && !hasStatusItem;
}

static inline BOOL HWGIconVisibilityNeedsStatusItemRemoval(HWGrowlIconState visibility, BOOL hasStatusItem)
{
	return !HWGIconVisibilityShowsMenuBarIcon(visibility) && hasStatusItem;
}
