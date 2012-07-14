//
//  BLYClient
//  Bully
//
//  Created by Sam Soffes on 6/1/12.
//  Copyright (c) 2012 Sam Soffes. All rights reserved.
//

#import "BLYClient.h"
#import "BLYClientPrivate.h"
#import "BLYChannel.h"
#import "BLYChannelPrivate.h"

@implementation BLYClient

@synthesize socketID = _socketID;
@synthesize delegate = _delegate;
@synthesize webSocket = _webSocket;
@synthesize url = _url;
@synthesize connectedChannels = _connectedChannels;

- (void)setWebSocket:(SRWebSocket *)webSocket {
	if (_webSocket) {
		_webSocket.delegate = nil;
		[_webSocket close];
	}
    
	_webSocket = webSocket;
	_webSocket.delegate = self;
}


+ (NSString *)version {
	return @"0.1.0";
}


- (id)initWithURL: (NSURL *)url delegate:(id<BLYClientDelegate>)delegate {
	if ((self = [super init])) {
		self.delegate = delegate;
        self.url = url;
		[self connect];
	}
	return self;
}


- (BLYChannel *)subscribeToChannelWithName:(NSString *)channelName {
	return [self subscribeToChannelWithName:channelName authenticationBlock:nil];
}


- (BLYChannel *)subscribeToChannelWithName:(NSString *)channelName authenticationBlock:(BLYChannelAuthenticationBlock)authenticationBlock {
	BLYChannel *channel = [_connectedChannels objectForKey:channelName];
	if (channel) {
		return channel;
	}
    
	channel = [[BLYChannel alloc] initWithName:channelName client:self authenticationBlock:authenticationBlock];
	[channel subscribe];
	[_connectedChannels setObject:channel forKey:channelName];
	return channel;
}


- (void)connect {
	if ([self isConnected]) {
		return;
	}
    
	self.webSocket = [[SRWebSocket alloc] initWithURL: self.url];
	[self.webSocket open];
    
	if (!self.connectedChannels) {
		self.connectedChannels = [[NSMutableDictionary alloc] init];
	}
}


- (void)disconnect {
	if (![self isConnected]) {
		return;
	}
	
	self.webSocket = nil;
	if ([self.delegate respondsToSelector:@selector(bullyClientDidDisconnect:)]) {
		[self.delegate bullyClientDidDisconnect:self];
	}
	self.socketID = nil;
}


- (BOOL)isConnected {
	return self.webSocket != nil;
}


#pragma mark - Private

- (void)_sendEvent:(NSString *)eventName dictionary:(NSDictionary *)dictionary {
	if (self.webSocket.readyState != SR_OPEN) {
		return;
	}
    
	NSMutableDictionary *object = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                                   eventName, @"event",
                                   nil];
    [object addEntriesFromDictionary: dictionary];
	[self.webSocket send:[NSJSONSerialization dataWithJSONObject:object options:0 error:nil]];
}


- (void)_reconnectChannels {
	for (NSString *channelName in self.connectedChannels) {
		BLYChannel *channel = [self.connectedChannels objectForKey:channelName];
		[channel subscribe];
	}
}


- (void)_removeChannel:(BLYChannel *)channel {
	if (!channel) {
		return;
	}
	
	[self.connectedChannels removeObjectForKey:channel.name];
}


#pragma mark - SRWebSocketDelegate

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)messageString {
    
	//NSLog(@"webSocket:didReceiveMessage: %@", messageString);
	
	NSData *messageData = [(NSString *)messageString dataUsingEncoding:NSUTF8StringEncoding];
	NSDictionary *message = [NSJSONSerialization JSONObjectWithData:messageData options:0 error:nil];
    
	NSString *eventName = [message objectForKey:@"event"];
    id data = [message objectForKey:@"data"];
	if (data && [data isKindOfClass:[NSString class]]) {
		NSData *eventMessageData = [data dataUsingEncoding:NSUTF8StringEncoding];
		data = [NSJSONSerialization JSONObjectWithData:eventMessageData options:0 error:nil];
	}
    
	if ([eventName isEqualToString:@"socky:connection:established"]) {
        
        // ToDo: Make option for socket id fiel dname
		self.socketID = [message objectForKey:@"connection_id"];
		if ([self.delegate respondsToSelector:@selector(bullyClientDidConnect:)]) {
			[self.delegate bullyClientDidConnect:self];
		}
		[self _reconnectChannels];
		return;
	}
    
	// Check for channel events
	NSString *channelName = [message objectForKey:@"channel"];
	if (channelName) {
		// Find channel
		BLYChannel *channel = [self.connectedChannels objectForKey:channelName];
        
		// Ensure the user is subscribed to the channel
		if (channel) {
			// See if they are binded to this event
			BLYChannelEventBlock block = [channel.subscriptions objectForKey:eventName];
			if (block) {
				// Call their block with the event data
				block(data);
			}
			return;
		}
        
#if DEBUG
		NSLog(@"[Bully] Event sent to unsubscribed channel: %@", message);
#endif
		return;
	}
    
	// Other events
#if DEBUG
	NSLog(@"[Bully] Unknown event: %@", message);
#endif
}


- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error {
    
	if ([self.delegate respondsToSelector:@selector(bullyClient:didReceiveError:)]) {
		[self.delegate bullyClient: self didReceiveError: error];
	}
	self.webSocket = nil;
}


- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
    
	[self disconnect];
}

@end
