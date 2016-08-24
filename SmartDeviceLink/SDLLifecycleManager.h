//
//  SDLLifecycleManager.h
//  SmartDeviceLink-iOS
//
//  Created by Joel Fischer on 7/19/16.
//  Copyright © 2016 smartdevicelink. All rights reserved.
//

#import "SDLNotificationConstants.h"
#import <Foundation/Foundation.h>


@class SDLConfiguration;
@class SDLFileManager;
@class SDLHMILevel;
@class SDLLanguage;
@class SDLLifecycleConfiguration;
@class SDLLockScreenConfiguration;
@class SDLLockScreenManager;
@class SDLNotificationDispatcher;
@class SDLOnHashChange;
@class SDLPermissionManager;
@class SDLProxy;
@class SDLPutFile;
@class SDLRegisterAppInterfaceResponse;
@class SDLResponseDispatcher;
@class SDLRPCNotification;
@class SDLRPCRequest;
@class SDLRPCResponse;
@class SDLStateMachine;
@class SDLStreamingMediaManager;

@protocol SDLManagerDelegate;


NS_ASSUME_NONNULL_BEGIN

typedef NSString SDLLifecycleState;
SDLLifecycleState *const SDLLifecycleStateDisconnected = @"TransportDisconnected";
SDLLifecycleState *const SDLLifecycleStateTransportConnected = @"TransportConnected";
SDLLifecycleState *const SDLLifecycleStateRegistered = @"Registered";
SDLLifecycleState *const SDLLifecycleStateSettingUpManagers = @"SettingUpManagers";
SDLLifecycleState *const SDLLifecycleStatePostManagerProcessing = @"PostManagerProcessing";
SDLLifecycleState *const SDLLifecycleStateUnregistering = @"Unregistering";
SDLLifecycleState *const SDLLifecycleStateReady = @"Ready";

typedef void (^SDLManagerReadyBlock)(BOOL success, NSError *_Nullable error);


@interface SDLLifecycleManager : NSObject

@property (copy, nonatomic, readonly) SDLConfiguration *configuration;
@property (weak, nonatomic, nullable) id<SDLManagerDelegate> delegate;
@property (strong, nonatomic, readonly, nullable) SDLRegisterAppInterfaceResponse *registerAppInterfaceResponse;

@property (strong, nonatomic) SDLFileManager *fileManager;
@property (strong, nonatomic) SDLPermissionManager *permissionManager;
@property (strong, nonatomic, readonly, nullable) SDLStreamingMediaManager *streamManager;
@property (strong, nonatomic) SDLLockScreenManager *lockScreenManager;

@property (strong, nonatomic, readonly) SDLNotificationDispatcher *notificationDispatcher;
@property (strong, nonatomic, readonly) SDLResponseDispatcher *responseDispatcher;

@property (strong, nonatomic, readonly) SDLStateMachine *lifecycleStateMachine;

// Deprecated internal proxy object
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
@property (strong, nonatomic, readonly, nullable) SDLProxy *proxy;
#pragma clang diagnostic pop

@property (assign, nonatomic, readonly) UInt16 lastCorrelationId;
@property (assign, nonatomic, readonly) SDLLifecycleState *lifecycleState;
@property (copy, nonatomic, readonly, nullable) SDLHMILevel *hmiLevel;

#pragma mark Lifecycle
/**
 *  Initialize the manager with a configuration. Call `startWithHandler` to begin waiting for a connection.
 *
 *  @param configuration Your app's unique configuration for setup.
 *  @param delegate An optional delegate to be notified of hmi level changes and startup and shutdown. It is recommended that you implement this.
 *
 *  @return An instance of SDLManager
 */
- (instancetype)initWithConfiguration:(SDLConfiguration *)configuration delegate:(nullable id<SDLManagerDelegate>)delegate NS_DESIGNATED_INITIALIZER;

/**
 *  Start the manager, which will tell it to start looking for a connection. Once one does, it will automatically run the setup process and call the readyBlock when done.
 *
 *  @param readyBlock The block called when the manager is ready to be used or an error occurs while attempting to become ready.
 */
- (void)startWithHandler:(SDLManagerReadyBlock)readyBlock;

/**
 *  Stop the manager, it will disconnect if needed and no longer look for a connection. You probably don't need to call this method ever.
 */
- (void)stop;

/**
 *  Call this method within your AppDelegate's `applicationWillTerminate` method to properly shut down SDL. If you do not, you will not be able to reregister with the remote device.
 */
- (void)applicationWillTerminate;


#pragma mark Send RPC Requests

/**
 *  Send an RPC request and don't bother with the response or error. If you need the response or error, call sendRequest:withCompletionHandler: instead.
 *
 *  @param request The RPC request to send
 */
- (void)sendRequest:(SDLRPCRequest *)request;

/**
 *  Send an RPC request and set a completion handler that will be called with the response when the response returns.
 *
 *  @param request The RPC request to send
 *  @param handler The handler that will be called when the response returns
 */
- (void)sendRequest:(SDLRPCRequest *)request withCompletionHandler:(nullable SDLRequestCompletionHandler)handler;

@end

NS_ASSUME_NONNULL_END