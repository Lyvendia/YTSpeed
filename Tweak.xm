#define DEFAULT_RATE 2.0f


@interface YTVarispeedSwitchControllerOption : NSObject
- (id)initWithTitle:(id)title rate:(float)rate;
@end


@interface YTPlayerViewController : NSObject
@property id activeVideo;
@property float playbackRate;
- (void)singleVideo:(id)video playbackRateDidChange:(float)rate;
@end


@interface MLHAMQueuePlayer : NSObject
@property id delegate;
- (void)setRate:(float)rate;
- (void)internalSetRate;
@end


@interface MLPlayerStickySettings : NSObject
- (void)setRate:(float)rate;
@end


@interface MLPlayerEventCenter : NSObject
- (void)broadcastRateChange:(float)rate;
@end


@interface YTSingleVideoController : NSObject
- (void)playerRateDidChange:(float)rate;
@end


@interface HAMPlayerInternal : NSObject
- (void)setRate:(float)rate;
@end


%hook YTVarispeedSwitchController

- (id)init {
	id result = %orig;

	const int size = 10;
	float speeds[] = {0.5, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0, 3.5, 4.0};
	id varispeedSwitchControllerOptions[size];

	for (int i = 0; i < size; ++i) {
		id title = [NSString stringWithFormat:@"%.2fx", speeds[i]];
		varispeedSwitchControllerOptions[i] = [[%c(YTVarispeedSwitchControllerOption) alloc] initWithTitle:title rate:speeds[i]];
	}

	NSUInteger count = sizeof(varispeedSwitchControllerOptions) / sizeof(id);
	NSArray *varispeedArray = [NSArray arrayWithObjects:varispeedSwitchControllerOptions count:count];
	MSHookIvar<NSArray *>(self, "_options") = varispeedArray;

	return result;
}

%end


%hook YTPlayerViewController

%property float playbackRate;

- (id)initWithServiceRegistryScope:(id)serviceRegistryScope parentResponder:(id)parentResponder overlayFactory:(id)overlayFactory {
	float savedRate = [[NSUserDefaults standardUserDefaults] floatForKey:@"YoutubeSpeed_PlaybackRate"];
	self.playbackRate = savedRate == 0 ? DEFAULT_RATE : savedRate;
	return %orig;
}

- (void)singleVideo:(id)video playbackRateDidChange:(float)rate {
	%orig;
}

- (float)currentPlaybackRateForVarispeedSwitchController:(id)varispeedSwitchController {
	return self.playbackRate;
}

- (void)varispeedSwitchController:(id)varispeedSwitchController didSelectRate:(float)rate {
	self.playbackRate = rate;
	[[NSUserDefaults standardUserDefaults] setFloat: rate forKey:@"YoutubeSpeed_PlaybackRate"];
	if (rate > 2.0f) {
		[self singleVideo:self.activeVideo playbackRateDidChange: rate];
	}
	%orig;
}

%end


%hook MLHAMQueuePlayer

- (id)initWithStickySettings:(id)stickySettings playerViewProvider:(id)playerViewProvider {
	id result = %orig;
	float savedRate = [[NSUserDefaults standardUserDefaults] floatForKey:@"YoutubeSpeed_PlaybackRate"];
	[self setRate: savedRate == 0 ? DEFAULT_RATE : savedRate];
	return result;
}

- (void)setRate:(float)rate {
	MSHookIvar<float>(self, "_rate") = rate;
	MSHookIvar<float>(self, "_preferredRate") = rate;

	id player = MSHookIvar<HAMPlayerInternal *>(self, "_player");
	[player setRate: rate];
	
	id stickySettings = MSHookIvar<MLPlayerStickySettings *>(self, "_stickySettings");
	[stickySettings setRate: rate];

	id playerEventCenter = MSHookIvar<MLPlayerEventCenter *>(self, "_playerEventCenter");
	[playerEventCenter broadcastRateChange: rate];

	YTSingleVideoController *singleVideoController = self.delegate;
	[singleVideoController playerRateDidChange: rate];
}

%end

