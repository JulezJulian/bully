//
//  BLYChannel
//  Bully
//
//  Created by Sam Soffes on 6/1/12.
//  Copyright (c) 2012 Sam Soffes. All rights reserved.
//

#import "BLYChannel.h"
#import "BLYChannelPrivate.h"
#import "BLYClientPrivate.h"

@implementation BLYChannel

@synthesize client = _client;
@synthesize name = _name;
@synthesize subscriptions = _subscriptions;
@synthesize authenticationBlock = _authenticationBlock;

- (id)initWithName:(NSString *)name client:(BLYClient *)client  authenticationBlock:(BLYChannelAuthenticationBlock)authenticationBlock {
	if ((self = [super init])) {
		self.name = name;
		self.client = client;
		self.authenticationBlock = authenticationBlock;
		self.subscriptions = [[NSMutableDictionary alloc] init];
	}
	return self;
}


- (void)bindToEvent:(NSString *)eventName block:(BLYChannelEventBlock)block {
	[self.subscriptions setObject:block forKey:eventName];
}


- (void)unbindEvent:(NSString *)eventName {
	[self.subscriptions removeObjectForKey:eventName];
}


- (void)unsubscribe {
	NSDictionary *dictionary = [[NSDictionary alloc] initWithObjectsAndKeys:
								self.name, @"channel",
								nil];
	[self.client _sendEvent:@"socky:unsubscribe" dictionary:dictionary];
	[self.client _removeChannel:self];
}


- (BOOL)isPrivate {
	return [self.name hasPrefix:@"private-"];
}

- (void)subscribe {
	if ([self isPrivate]) {
        
		if (!self.client.socketID) {
			return;
		}
		
		if (self.authenticationBlock) {
			self.authenticationBlock(self);
		}
		return;
	}
    
	[self subscribeWithAuthentication:nil];
}

- (void)subscribeWithAuthentication:(NSDictionary *)authentication {
	NSDictionary *dictionary = nil;
	if (authentication) {
		dictionary = [[NSDictionary alloc] initWithObjectsAndKeys:
					  self.name, @"channel",
					  [authentication objectForKey:@"auth"], @"auth",
					  nil];
	} else {
		dictionary = [[NSDictionary alloc] initWithObjectsAndKeys:
					  self.name, @"channel",
					  nil];
	}
	[self.client _sendEvent:@"socky:subscribe" dictionary:dictionary];
}


- (NSDictionary *)authenticationParameters {
	return [[NSDictionary alloc] initWithObjectsAndKeys:
			self.name, @"channel",
			self.client.socketID, @"connection_id",
			nil];
}

- (NSData *)authenticationParametersData {
	return [NSJSONSerialization dataWithJSONObject:self.authenticationParameters options:0 error:nil];
}


@end
