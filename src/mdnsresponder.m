#include "mdnsresponder.h"

#import <Foundation/Foundation.h>

#include <netinet/in.h>
#include <sys/errno.h>
#include <string.h>
#include <stdio.h>

#include "debug.h"


@interface MDNSServer : NSObject <NSNetServiceDelegate>
@property (nonatomic, strong) NSMutableArray <NSNetService*> *services;
@property (nonatomic, strong) NSMutableData *txtRecordData;
@property (nonatomic, strong) NSMutableDictionary <NSString*, NSData*> *TXTRecordDictionary;
@end

@implementation MDNSServer

-(instancetype) init {
    if (self = [super init]) {
        _services = [NSMutableArray new];
        _txtRecordData = [NSMutableData new];
        _TXTRecordDictionary = [NSMutableDictionary new];
    }
    return self;
}

- (void)netServiceDidPublish:(NSNetService *)sender {
    DEBUG("%s", sender.description.UTF8String);
}

- (void)netService:(NSNetService *)sender didNotPublish:(NSDictionary<NSString *,NSNumber *> *)errorDict {
    NSLog(@"Error: %@", errorDict);
}

- (void)netServiceDidStop:(NSNetService *)sender {
    NSLog(@"netServiceDidStop");
    
}

- (void)netService:(NSNetService *)sender didUpdateTXTRecordData:(NSData *)data {
    NSLog(@"didUpdateTXTRecordData: %@", data);
}

@end
static MDNSServer *server;

// Starts the mDNS responder task, call first
void mdns_init() {
    DEBUG("mdns_init");
    server = [MDNSServer new];
}


// Clear all records
void mdns_clear() {
    DEBUG("");
}

void mdns_add_facility( const char* instanceName,   // Short user-friendly instance name, should NOT include serial number/MAC/etc
                       const char* serviceName,    // Must be registered, _name, (see RFC6335 5.1 & 5.2)
                       const char* addText,        // Should be <key>=<value>, or "" if unused (see RFC6763 6.3)
                       mdns_flags  flags,          // TCP or UDP plus browsable
                       u16_t       onPort,         // port number
                       u32_t       ttl             // time-to-live, seconds
) {
    
    DEBUG("");
    NSString *instName = [[NSString alloc] initWithCString:instanceName encoding:NSASCIIStringEncoding];
    NSString *servName = [[NSString alloc] initWithCString:serviceName encoding:NSASCIIStringEncoding];
    //    NSString *textName = [[NSString alloc] initWithCString:addText encoding:NSASCIIStringEncoding];
    switch (flags) {
        case mdns_TCP:
            servName = [servName stringByAppendingString:@"._tcp"];
            break;

        default:
            break;
    }
    dispatch_sync(dispatch_get_main_queue(), ^{

        NSNetService *service = server.services.firstObject;
        BOOL success = NO;
        if (service == nil) {
            service = server.services.firstObject ?: [[NSNetService alloc] initWithDomain:@"local" type:servName name:instName port:onPort];
            success = [service setTXTRecordData:[NSNetService dataFromTXTRecordDictionary:server.TXTRecordDictionary]];
            service.delegate = server;
            [service publish];

            [server.services addObject:service];
        } else {
            success = [service setTXTRecordData:[NSNetService dataFromTXTRecordDictionary:server.TXTRecordDictionary]];
            DEBUG("Change txt record: %d", success);
        }
        if (!success) {
            ERROR("mdns_add_facility: error set TXTRecordDictionary");
        }

        // clean records
        [server.TXTRecordDictionary removeAllObjects];
    });
}


// Low-level RR builders for rolling your own
void mdns_add_PTR(const char* rKey, u32_t ttl, const char* nameStr) {
    ERROR("mdns_add_PTR");
}
void mdns_add_SRV(const char* rKey, u32_t ttl, u16_t rPort, const char* targname) {
    ERROR("mdns_add_SRV");
}
void mdns_add_TXT(const char* rKey, u32_t ttl, const char* txtStr) {
    ERROR("mdns_add_TXT");
    
}
void mdns_add_A  (const char* rKey, u32_t ttl, const ip4_addr_t *addr) {
    ERROR("mdns_add_A");
}
#if LWIP_IPV6
void mdns_add_AAAA(const char* rKey, u32_t ttl, const ip6_addr_t *addr) {
    ERROR("mdns_add_AAAA");
}
#endif

void mdns_TXT_append(char* txt, size_t txt_size, const char* record, size_t record_size) {
    DEBUG("Add record: %s", record);
    NSString *recordTXT = [NSString stringWithCString:record encoding:NSASCIIStringEncoding];

    NSArray <NSString*> *cmps = [recordTXT componentsSeparatedByString:@"="];
    if (cmps.count == 2) {
        const char *dataStr = [cmps[1] cStringUsingEncoding:NSUTF8StringEncoding];
        NSData *data = [NSData dataWithBytes:dataStr length:strlen(dataStr)];
        [server.TXTRecordDictionary setValue:data forKey:cmps[0]];
    } else {
        NSLog(@"Error append txt: %s", record);
    }
}




