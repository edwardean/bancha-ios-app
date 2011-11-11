//
//  Api.m
//  Bancha
//
//  Created by Nicholas Valbusa on 04/11/11.
//  Copyright (c) 2011 Squallstar Studio. All rights reserved.
//

#import "Api.h"
#import "IOSBoilerplateAppDelegate.h"

@implementation Api

@synthesize delegate, client;

-(id)init {
	self = [super init];
    
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"api_url"]) {
        self.client = [[AFHTTPClient alloc] initWithBaseURL:[NSURL URLWithString:[[NSUserDefaults standardUserDefaults] objectForKey:@"api_url"]]];
    } else {
        self.client = [[AFHTTPClient alloc] initWithBaseURL:[NSURL URLWithString:@""]];
    }	
    
    [self.client setStringEncoding:NSUTF8StringEncoding];
    [self.client setParameterEncoding:AFFormURLParameterEncoding];
	
	return self;
}

-(BOOL)loginToPath:(NSString*)adminPath withUsername:(NSString*)username andPassword:(NSString*)password {
	
	
	NSMutableCharacterSet *set = [NSMutableCharacterSet characterSetWithCharactersInString:@"/"];
	
	NSString *trimmedUri = [adminPath stringByTrimmingCharactersInSet:set];
	
	[self.client release];
    
    NSString *baseUrl = [NSString stringWithFormat:@"http://%@/api/", trimmedUri];
    
	self.client = [[AFHTTPClient alloc] initWithBaseURL:[NSURL URLWithString:baseUrl]];
    [self.client setStringEncoding:NSUTF8StringEncoding];
    [self.client setParameterEncoding:AFFormURLParameterEncoding];
	
	NSURLRequest *request = [self.client requestWithMethod:@"POST" path:@"login" parameters:[NSDictionary dictionaryWithObjectsAndKeys:username, @"username", password, @"password", nil]];

	AFJSONRequestOperation *operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {

		NSString *msg = [JSON valueForKeyPath:@"message"];
		if ([msg isEqualToString:@"USER_PWD_WRONG"]) {
			NSLog(@"%@", JSON);
			UIAlertView *al = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Username or password wrong." delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
			[al show];
			[al release];
            
            [delegate loginFinished:NO];
			
		} else if ([msg isEqualToString:@"OK"]) {
			//Success!
            NSString *token = [[JSON valueForKeyPath:@"data"] valueForKeyPath:@"token"];
            
            [[NSUserDefaults standardUserDefaults] setObject:token forKey:@"api_token"];
            [[NSUserDefaults standardUserDefaults] setObject:baseUrl forKey:@"api_url"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            [delegate loginFinished:YES];
		}
		
		
	} failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error){
		NSLog(@"%@", error);
        [delegate loginFinished:NO];
	}];
	
	NSOperationQueue *queue = [[[NSOperationQueue alloc] init] autorelease];
	[queue addOperation:operation];
	
	
	return NO;	
}

-(void)getContentTypes {
    
    NSURLRequest *request = [self.client requestWithMethod:@"POST" path:@"types" parameters:[NSDictionary dictionaryWithObjectsAndKeys:[[NSUserDefaults standardUserDefaults] objectForKey:@"api_token"], @"token", nil]];
    
	AFJSONRequestOperation *operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
        
		NSString *msg = [JSON valueForKeyPath:@"message"];
		if (![msg isEqualToString:@"OK"]) {
			
            
            if ([msg isEqualToString:@"BAD_TOKEN"]) {
                [self tokenInvalidScript];
            } else {
                UIAlertView *al = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Cannot receive the Content types." delegate:nil cancelButtonTitle:@"Try later" otherButtonTitles:nil];
                [al show];
                [al release];
            }
			
		} else {
			//Success!
            NSDictionary *types = [JSON objectForKey:@"data"];
            [[NSUserDefaults standardUserDefaults] setObject:types forKey:@"content_types"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            
             NSLog(@"Content types has been renewed with %i types.", [[types allKeys] count]);
            [delegate typesFinished:YES];
		}
		
	} failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error){
		NSLog(@"%@", error);
        [delegate typesFinished:NO];
	}];
    
    NSOperationQueue *queue = [[[NSOperationQueue alloc] init] autorelease];
	[queue addOperation:operation];
    
}

-(void)getRecordsByActiveQuery:(NSString*)activeQuery {
    NSLog(@"calling mama with token %@", [[NSUserDefaults standardUserDefaults] objectForKey:@"api_token"]);
    NSURLRequest *request = [self.client requestWithMethod:@"POST" path:@"records" parameters:[NSDictionary dictionaryWithObjectsAndKeys:[[NSUserDefaults standardUserDefaults] objectForKey:@"api_token"], @"token", activeQuery, @"query", nil]];
    
    AFJSONRequestOperation *operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
        NSLog(@"%@", JSON);
		NSString *msg = [JSON valueForKeyPath:@"message"];
		if ([msg isEqualToString:@"BAD_QUERY"]) {
			
			UIAlertView *al = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Bad query!" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
			[al show];
			[al release];
			
		} else if ([msg isEqualToString:@"NO_RECORDS"]) {            
            if (delegate != nil) {
                [delegate recordsObtained:[NSArray array] forActiveQuery:activeQuery];
            }			
		} else if ([msg isEqualToString:@"OK"]) {
			//Success!
            NSArray *records = [[JSON objectForKey:@"data"] objectForKey:@"records"];
            
            NSLog(@"Obtained %i records.", [records count]);
            if (delegate != nil) {
                [delegate recordsObtained:records forActiveQuery:activeQuery];
            }
		} else if ([msg isEqualToString:@"BAD_TOKEN"]) {      
            [self tokenInvalidScript];
		}
		
		
	} failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error){
		NSLog(@"%@", error);
        [delegate typesFinished:NO];
	}];
    
    NSOperationQueue *queue = [[[NSOperationQueue alloc] init] autorelease];
	[queue addOperation:operation];
}

-(void)tokenInvalidScript {
    NSLog(@"Token invalid. Logging out!");
    
    UIAlertView *a = [[UIAlertView alloc] initWithTitle:@"Token invalid" message:@"Your token is not valid. Please log-in again to obtain a new token." delegate:nil cancelButtonTitle:@"Dismiss" otherButtonTitles: nil];
    [a show];
    [a release];
    
    [[IOSBoilerplateAppDelegate sharedAppDelegate] clearUserData];
    [[IOSBoilerplateAppDelegate sharedAppDelegate] switchToLogin];
}



@end
