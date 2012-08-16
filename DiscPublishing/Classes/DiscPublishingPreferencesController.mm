//
//  DiscPublishingPreferencesController.mm
//  DiscPublishing
//
//  Created by Alessandro Volz on 4/26/10.
//  Copyright 2010 OsiriX Team. All rights reserved.
//

#import "DiscPublishingPreferencesController.h"
#import "DiscPublishingPreferencesController+RobotOptions.h"
#import "NSUserDefaultsController+DiscPublishing.h"
#import <OsiriXAPI/NSUserDefaultsController+N2.h>
#import <OsiriXAPI/N2Shell.h>
#import <OsiriXAPI/DiscBurningOptions.h>
#import "DiscPublishing.h"
#import <OsiriXAPI/N2Operators.h>
#import <OsiriXAPI/NSUserDefaultsController+OsiriX.h>
#import <OsiriXAPI/PreferencesWindowController.h>
#import <OsiriXAPI/Anonymization.h>
#import "DiscPublishingUtils.h"

@interface NSPathControl (DiscPublishing)
-(NSRect)usedFrame;
@end @implementation NSPathControl (DiscPublishing)

-(NSRect)usedFrame {
	return [self.cell rectOfPathComponentCell:[[self.cell pathComponentCells] lastObject] withFrame:self.frame inView:self];
}

@end

/*@interface NSUserDefaults (DP)

-(NSMutableDictionary*)DP_mutableDictionaryValueForKey:(NSString*)key;

@end

@interface DPDictionaryController : NSDictionaryController

@end
*/
/*
@interface DPMutableDictionary : NSMutableDictionary {
    NSMutableDictionary* _storage;
    NSUserDefaults* _ud;
    NSString* _key;
}

+(id)dictionaryInUserDefaults:(NSUserDefaults*)ud key:(NSString*)key;
-(id)initInUserDefaults:(NSUserDefaults*)ud key:(NSString*)key;

@end*/

@interface DiscPublishingPreferencesController ()

-(void)updateBindings;

@end

@implementation DiscPublishingPreferencesController

-(void)awakeFromNib {
	[super awakeFromNib];
	
//	[[NSUserDefaultsController sharedUserDefaultsController] add];
	
	deltaFromPathControlBRToButtonTL = NSZeroSize+patientModeLabelTemplateEditButton.frame.origin - (patientModeLabelTemplatePathControl.frame.origin+patientModeLabelTemplatePathControl.frame.size);
	
	NSUserDefaultsController* defaultsController = [NSUserDefaultsController sharedUserDefaultsController];
	[defaultsController addObserver:self forValuesKey:DiscPublishingBurnModeDefaultsKey options:NSKeyValueObservingOptionInitial context:NULL];
	[defaultsController addObserver:self forValuesKey:DiscPublishingPatientModeDiscCoverTemplatePathDefaultsKey options:NSKeyValueObservingOptionInitial context:NULL];
	[defaultsController addObserver:self forValuesKey:DiscPublishingArchivingModeDiscCoverTemplatePathDefaultsKey options:NSKeyValueObservingOptionInitial context:NULL];
	
	NSString* zipPasswordToolTip = NSLocalizedString(@"The password must be at least 8 characters long. If this condition is not met then the password will not be applied.", @"Preferences password warning");
	[patientModeZipPasswordWarningView setToolTip:zipPasswordToolTip];
	[archivingModeZipPasswordWarningView setToolTip:zipPasswordToolTip];
	NSString* auxDirToolTip = NSLocalizedString(@"The auxiliary directory must point to an existing directory. If the selected directory does not exist then no files are copied.", @"Preferences auxiliary directory warning");
	[patientModeAuxiliaryDirWarningView setToolTip:auxDirToolTip];
	[archivingModeAuxiliaryDirWarningView setToolTip:auxDirToolTip];

	[self robotOptionsInit];
    
    [self updateBindings];
}

-(void)dealloc {
    [_serviceControllerId release];
    [_serviceController release];
    [_services dealloc];
    
	[self robotOptionsDealloc];
	[[NSUserDefaultsController sharedUserDefaultsController] removeObserver:self forValuesKey:DiscPublishingBurnModeDefaultsKey];
	[[NSUserDefaultsController sharedUserDefaultsController] removeObserver:self forValuesKey:DiscPublishingPatientModeDiscCoverTemplatePathDefaultsKey];
	[[NSUserDefaultsController sharedUserDefaultsController] removeObserver:self forValuesKey:DiscPublishingArchivingModeDiscCoverTemplatePathDefaultsKey];
	[super dealloc];
}

-(void)observeValueForKeyPath:(NSString*)keyPath ofObject:(id)obj change:(NSDictionary*)change context:(void*)context {
	//NSLog(@"prefs observeValueForKeyPath:%@", keyPath);

	NSUserDefaultsController* defaultsController = [NSUserDefaultsController sharedUserDefaultsController];
	if (obj == defaultsController) {
		if ([keyPath isEqual:DP_valuesKeyPath(DiscPublishingBurnModeDefaultsKey)]) {
			switch ([[defaultsController valueForKeyPath:keyPath] intValue]) {
				case BurnModeArchiving: [burnModeOptionsBox setContentView:archivingModeOptionsView]; break;
				case BurnModePatient: [burnModeOptionsBox setContentView:patientModeOptionsView]; break;
			}
			return;
		} else
		if ([keyPath isEqual:DP_valuesKeyPath(DiscPublishingPatientModeDiscCoverTemplatePathDefaultsKey)]) {
			[patientModeLabelTemplateEditButton setFrameOrigin:RectBR([patientModeLabelTemplatePathControl usedFrame])+deltaFromPathControlBRToButtonTL];
			return;
		} else
		if ([keyPath isEqual:DP_valuesKeyPath(DiscPublishingArchivingModeDiscCoverTemplatePathDefaultsKey)]) {
			[archivingModeLabelTemplateEditButton setFrameOrigin:RectBR([archivingModeLabelTemplatePathControl usedFrame])+deltaFromPathControlBRToButtonTL];
			return;
		}
	}
	
	if ([self robotOptionsObserveValueForKeyPath:keyPath ofObject:obj change:change context:context])
		return;
	
	[super observeValueForKeyPath:keyPath ofObject:obj change:change context:context];
}

-(IBAction)showPatientModeAnonymizationOptionsSheet:(id)sender {
	[Anonymization showPanelForDefaultsKey:DiscPublishingPatientModeAnonymizationTagsDefaultsKey modalForWindow:self.mainView.window modalDelegate:NULL didEndSelector:NULL representedObject:NULL];
}

-(void)fileSelectionSheetDidEnd:(NSOpenPanel*)openPanel returnCode:(int)returnCode contextInfo:(void*)context {
	NSString* key = (id)context;
	if (returnCode == NSOKButton) {
		[[NSUserDefaultsController sharedUserDefaultsController] setValue:openPanel.URL.path forValuesKey:key];
	}
}

-(void)showDirSelectionSheetForKey:(NSString*)key {
	NSOpenPanel* openPanel = [NSOpenPanel openPanel];
	[openPanel setCanChooseFiles:NO];
	[openPanel setCanChooseDirectories:YES];
	[openPanel setAllowsMultipleSelection:NO];
	
	NSString* location = [[NSUserDefaultsController sharedUserDefaultsController] stringForKey:key];
	
	[openPanel beginSheetForDirectory:[location stringByDeletingLastPathComponent] file:[location lastPathComponent] types:NULL modalForWindow:self.mainView.window modalDelegate:self didEndSelector:@selector(fileSelectionSheetDidEnd:returnCode:contextInfo:) contextInfo:key];	
}

-(IBAction)showPatientModeAuxiliaryDirSelectionSheet:(id)sender {
	[self showDirSelectionSheetForKey:DiscPublishingPatientModeAuxiliaryDirectoryPathDefaultsKey];
}

-(IBAction)showArchivingModeAuxiliaryDirSelectionSheet:(id)sender {
	[self showDirSelectionSheetForKey:DiscPublishingArchivingModeAuxiliaryDirectoryPathDefaultsKey];
}

-(void)showFileSelectionSheetForKey:(NSString*)key fileTypes:(NSArray*)types defaultLocation:(NSString*)defaultLocation {
	NSOpenPanel* openPanel = [NSOpenPanel openPanel];
	[openPanel setCanChooseFiles:YES];
	[openPanel setCanChooseDirectories:NO];
	[openPanel setAllowsMultipleSelection:NO];
	[openPanel setTreatsFilePackagesAsDirectories:NO];
	
	NSString* location = [[NSUserDefaultsController sharedUserDefaultsController] stringForKey:key];
	if (!location) location = defaultLocation;
	
	[openPanel beginSheetForDirectory:[location stringByDeletingLastPathComponent] file:[location lastPathComponent] types:types modalForWindow:self.mainView.window modalDelegate:self didEndSelector:@selector(fileSelectionSheetDidEnd:returnCode:contextInfo:) contextInfo:key];	
}

-(void)showDiscCoverFileSelectionSheetForKey:(NSString*)key {
	[self showFileSelectionSheetForKey:key fileTypes:[NSArray arrayWithObject:@"dcover"] defaultLocation:[DiscPublishing discCoverTemplatesDirPath]];
}

-(IBAction)showPatientModeDiscCoverFileSelectionSheet:(id)sender {
	[self showDiscCoverFileSelectionSheetForKey:DiscPublishingPatientModeDiscCoverTemplatePathDefaultsKey];
}

-(IBAction)showArchivingModeDiscCoverFileSelectionSheet:(id)sender {
	[self showDiscCoverFileSelectionSheetForKey:DiscPublishingArchivingModeDiscCoverTemplatePathDefaultsKey];
}

-(void)editDiscCoverFileWithKey:(NSString*)key {
	NSString* location = [[NSUserDefaultsController sharedUserDefaultsController] stringForKey:key];
	
	if (!location || ![[NSFileManager defaultManager] fileExistsAtPath:location]) {
		location = [[DiscPublishing discCoverTemplatesDirPath] stringByAppendingPathComponent:@"Template.dcover"];
		if (![[NSFileManager defaultManager] fileExistsAtPath:location])
			[[NSFileManager defaultManager] copyItemAtPath:[NSUserDefaultsController discPublishingDefaultDiscCoverPath] toPath:location error:NULL];
		[[NSUserDefaultsController sharedUserDefaultsController] setValue:location forValuesKey:key];
	}
	
	[N2Shell execute:@"/usr/bin/open" arguments:[NSArray arrayWithObjects: location, @"-a", [[[NSBundle bundleForClass:[self class]] bundlePath] stringByAppendingPathComponent:@"../DiscPublishingTool.app/Contents/Frameworks/PTRobot.framework/Resources/Disc Cover 3 PE.app"], NULL]];
	[[NSWorkspace sharedWorkspace] openFile:location];
}

-(IBAction)editPatientModeDiscCoverFile:(id)sender {
	[self editDiscCoverFileWithKey:DiscPublishingPatientModeDiscCoverTemplatePathDefaultsKey];
}

-(IBAction)editArchivingModeDiscCoverFile:(id)sender {
	[self editDiscCoverFileWithKey:DiscPublishingArchivingModeDiscCoverTemplatePathDefaultsKey];
}

-(IBAction)mediaCapacityValueChanged:(id)sender {
	// do nothing
}

#pragma mark Services

+ (NSString*) stringWithUUID {
    CFUUIDRef	uuidObj = CFUUIDCreate(nil);//create a new UUID
    //get the string representation of the UUID
    NSString	*uuidString = (NSString*)CFUUIDCreateString(nil, uuidObj);
    CFRelease(uuidObj);
    return [uuidString autorelease];
}

-(IBAction)manageServices:(id)sender {
    [NSApp beginSheet:servicesWindow modalForWindow:servicesPopUpButton.window modalDelegate:nil didEndSelector:nil contextInfo:nil];
    [servicesWindow makeKeyAndOrderFront:self];
}

-(NSString*)userDefaultsKeyForServiceId:(NSString*)sid {
    return [@"DiscPublishing Service " stringByAppendingString:sid];
}

-(NSArrayController*)services {
    if (!_services) {
        NSMutableArray* ma = [[NSUserDefaults standardUserDefaults] mutableArrayValueForKey:@"DiscPublishingServicesList"];
        _services = [[NSArrayController alloc] initWithContent:ma];
        _services.automaticallyRearrangesObjects = NO;
        
        [_services setSortDescriptors:[NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES selector:@selector(caseInsensitiveCompare:)]]];
    }
    return _services;
}

-(IBAction)addService:(id)sender {
    NSString* uid = [[self class] stringWithUUID];
    NSDictionary* dic = [NSMutableDictionary dictionaryWithObjectsAndKeys: uid, @"id", nil];
    [NSUserDefaults.standardUserDefaults setValue:[NSDictionary dictionary] forKey:[self userDefaultsKeyForServiceId:uid]];
    [self.services addObject:dic];
}

-(IBAction)removeService:(id)sender {
    NSArray* dicts = [self.services selectedObjects];
    
    [self.services remove:sender];
    
    for (NSDictionary* dict in dicts)
        [NSUserDefaults.standardUserDefaults removeObjectForKey:[self userDefaultsKeyForServiceId:[dict objectForKey:@"id"]]];
}

-(IBAction)endSheet:(id)sender {
    [NSApp endSheet:[sender window]];
    [[sender window] orderOut:self];
}

-(void)menuWillOpen:(NSMenu*)menu {
    NSArray* services = [[self services] arrangedObjects];

    // remove services and separators from menu
    while ([[menu itemAtIndex:1] representedObject] || [[menu itemAtIndex:1] isSeparatorItem])
        [menu removeItemAtIndex:1];
    
    // add items
    
    if (!services.count)
        return; // no items...
    
//    [menu insertItem:[NSMenuItem separatorItem] atIndex:menu.numberOfItems-1];
    
    for (NSDictionary* service in services) {
        NSString* title = [service objectForKey:@"name"];
        if (!title.length) title = NSLocalizedString(@"No Name", nil);
        NSMenuItem* mi = [[NSMenuItem alloc] initWithTitle:title action:@selector(selectService:) keyEquivalent:@""];
        mi.target = self;
        mi.representedObject = [service objectForKey:@"id"];
        [menu insertItem:mi atIndex:menu.numberOfItems-1];
    }
    
    [menu insertItem:[NSMenuItem separatorItem] atIndex:menu.numberOfItems-1];
}

-(IBAction)selectService:(NSMenuItem*)sender {
    [self willChangeValueForKey:@"selectedServiceId"];
    
    [servicesPopUpButton selectItem:sender];
   // [servicesPopUpButton setTitle:[sender title]];
    [self updateBindings];

    [self didChangeValueForKey:@"selectedServiceId"];
}

-(NSString*)selectedServiceId {
    return [[servicesPopUpButton selectedItem] representedObject];
}

+ (NSSet*)keyPathsForValuesAffectingValueForKey:(NSString*)key {
    NSSet* keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
    
    if ([key hasPrefix:@"Service"])
        return [keyPaths setByAddingObject:@"selectedServiceId"];
    
    return keyPaths;
}

-(void)updateBindings {
    NSArray* sk = [NSArray arrayWithObjects:
                    @"IncludeAuxiliaryDirectoryFlag",
                    @"IncludeReportsFlag",
                    @"AnonymizeFlag",
                    @"BurnDelay",
                    @"IncludeWeasisFlag",
                    @"IncludeHTMLQTFlag",
                    @"ZipFlag",
                    @"DiscCoverTemplatePath",
                    @"ZipEncryptFlag",
                    @"ZipEncryptPassword",
                    @"AuxiliaryDirectoryPathData",
                    @"IncludeOsirixLiteFlag",
                    @"IncludeFSMatch",
                    @"Compression",
                    @"CompressJPEGNotJPEG2000",
                    @"MatchedAETs",
                   nil];
    
    NSString* prefix = @"values.DiscPublishingPatientMode";
    NSString* ssid = self.selectedServiceId;
    if (ssid.length) {
        prefix = [NSString stringWithFormat:@"values.DiscPublishingPatientMode_%@_", [ssid stringByReplacingOccurrencesOfString:@"-" withString:@"_"]];
        
        
        
    }
    
/*	NSDictionary* options = [NSDictionary dictionaryWithObjectsAndKeys: [NSNumber numberWithBool:TRUE], NSRaisesForNotApplicableKeysBindingOption, NULL];

    for (NSString* isk in sk) {
        [self unbind:isk];
        [self bind:[@"Service" stringByAppendingString:isk] toObject:[NSUserDefaultsController sharedUserDefaultsController] withValuesKey:[prefix stringByAppendingString:isk] options:options];
    }*/
    
    NSMutableArray* views = [NSMutableArray arrayWithObject:burnModeOptionsBox];
    while (views.count) {
        NSView* view = [views objectAtIndex:0];
        [views removeObjectAtIndex:0];
        
        NSMutableArray* sviews = [NSMutableArray arrayWithArray:view.subviews];
        if ([view isKindOfClass:[NSTabView class]])
            for (NSTabViewItem* tvi in [(NSTabView*)view tabViewItems])
                if (![sviews containsObject:tvi.view])
                    [sviews addObject:tvi.view];
        [views addObjectsFromArray:sviews];
        
        NSArray* bindings = [view exposedBindings];
        for (NSString* binding in [view exposedBindings]) {
            NSDictionary* bindingInfo = [view infoForBinding:binding];
            if (bindingInfo) {
                NSString* okp = [bindingInfo objectForKey:NSObservedKeyPathKey];
                if (![okp hasPrefix:@"values.DiscPublishingPatientMode"])
                    continue;
                
                NSString* sk = [okp substringFromIndex:[@"values.DiscPublishingPatientMode" length]];
                NSInteger skspace = [sk rangeOfString:@"_" options:NSBackwardsSearch].location;
                if (skspace != NSNotFound)
                    sk = [sk substringFromIndex:skspace+1];
                
                NSString* nkp = [prefix stringByAppendingString:sk];
                
                NSLog(@"%@ %@: %@ -> %@ ", view, binding, okp, nkp);
                
                [view unbind:binding];
                [view bind:binding toObject:[bindingInfo objectForKey:NSObservedObjectKey] withKeyPath:nkp options:[bindingInfo objectForKey:NSOptionsKey]];
            }
        }
    }
}


@end

#pragma mark Value Transformers

@interface CompressionIsCompress: NSValueTransformer
@end
@implementation CompressionIsCompress

+(Class)transformedValueClass {
	return [NSNumber class];
}

+(BOOL)allowsReverseTransformation {
	return NO;
}

-(id)transformedValue:(id)value {
    return [NSNumber numberWithBool: [value intValue] == CompressionCompress];
}

@end


@interface DiscPublishingIsValidPassword : NSValueTransformer
@end
@implementation DiscPublishingIsValidPassword

+(Class)transformedValueClass {
	return [NSNumber class];
}

+(BOOL)allowsReverseTransformation {
	return NO;
}

-(id)transformedValue:(NSString*)value {
    return [NSNumber numberWithBool:[NSUserDefaultsController discPublishingIsValidPassword:value]];
}

@end


@interface DiscPublishingIsValidDirPath: NSValueTransformer
@end
@implementation DiscPublishingIsValidDirPath

+(Class)transformedValueClass {
	return [NSNumber class];
}

+(BOOL)allowsReverseTransformation {
	return NO;
}

-(id)transformedValue:(NSString*)value {
	BOOL isDir, exists = [[NSFileManager defaultManager] fileExistsAtPath:value isDirectory:&isDir];
    return [NSNumber numberWithBool: exists&&isDir];
}

@end


@interface DiscCoverTemplatePathTransformer: NSValueTransformer
@end
@implementation DiscCoverTemplatePathTransformer

+(Class)transformedValueClass {
	return [NSString class];
}

+(BOOL)allowsReverseTransformation {
	return NO;
}

-(id)transformedValue:(NSString*)value {
	if (!value | ![[NSFileManager defaultManager] fileExistsAtPath:value])
		return NSLocalizedString(@"/Standard Disc Cover Template", NULL);
	return value;
}

@end


@interface DiscPublishingAuxDirPathTransformer: NSValueTransformer
@end
@implementation DiscPublishingAuxDirPathTransformer

+(Class)transformedValueClass {
	return [NSString class];
}

+(BOOL)allowsReverseTransformation {
	return NO;
}

-(id)transformedValue:(NSString*)value {
	if (!value || ![[NSFileManager defaultManager] fileExistsAtPath:value])
		return NSLocalizedString(@"/Undefined", NULL);
	return value;
}

@end


@interface DiscPublishingPreferencesOptionsBoxTitleForMode: NSValueTransformer
@end
@implementation DiscPublishingPreferencesOptionsBoxTitleForMode

+(Class)transformedValueClass {
	return [NSString class];
}

+(BOOL)allowsReverseTransformation {
	return NO;
}

-(id)transformedValue:(id)value {
	switch ([value intValue]) {
		case BurnModeArchiving: return NSLocalizedString(@"Options for Archiving mode", NULL);
		case BurnModePatient: return NSLocalizedString(@"Options for Patient mode", NULL);
	}
	
	return NSLocalizedString(@"Options", NULL);
}

@end


@interface DPArrayIsNotEmpty: NSValueTransformer
@end
@implementation DPArrayIsNotEmpty

+(Class)transformedValueClass {
	return [NSNumber class];
}

+(BOOL)allowsReverseTransformation {
	return NO;
}

-(id)transformedValue:(id)value {
	return [NSNumber numberWithBool:([value count] > 0)];
}

@end

/*

@implementation DPMutableDictionary

- (id)initWithObjects:(NSArray*)objects forKeys:(NSArray*)keys inUserDefaults:(NSUserDefaults*)ud key:(NSString*)key {
    if ((self = [super init])) {
        _storage = [[NSMutableDictionary alloc] initWithObjects:objects forKeys:keys];
        _ud = [ud retain];
        _key = [key retain];
    }
    
    return self;
}

- (id)initInUserDefaults:(NSUserDefaults*)ud key:(NSString*)key {
    NSDictionary* value = [ud objectForKey:key];
    return [self initWithObjects:[value allValues] forKeys:[value allKeys] inUserDefaults:ud key:key];
}

+ (id)dictionaryInUserDefaults:(NSUserDefaults*)ud key:(NSString*)key {
    return [[[self alloc] initInUserDefaults:ud key:key] autorelease];
}

-(void)dealloc {
    [_key release];
    [_ud release];
    [_storage release];
    [super dealloc];
}

- (id)initWithObjects:(NSArray*)objects forKeys:(NSArray*)keys {
    return [self initWithObjects:objects forKeys:keys inUserDefaults:nil key:nil];
}

- (NSUInteger)count {
    return [_storage count];
}

- (id)objectForKey:(id)key {
    return [_storage objectForKey:key];
}

- (NSEnumerator*)keyEnumerator {
    return [_storage keyEnumerator];
}

- (void)setObject:(id)value forKey:(id)key {
    [self willChangeValueForKey:key];
    [_storage setObject:value forKey:key];
    [_ud setObject:self forKey:_key];
    [self didChangeValueForKey:key];
}

- (void)removeObjectForKey:(id)key {
    [self willChangeValueForKey:key];
    [_storage removeObjectForKey:key];
    [_ud setObject:self forKey:_key];
    [self didChangeValueForKey:key];
}

- (id)valueForKey:(NSString*)key {
    return [_storage objectForKey:key];
}

- (void)setValue:(id)value forKey:(NSString*)key {
    [self setObject:value forKey:key];
}

@end*/


/*@implementation NSUserDefaults (DP)

- (NSMutableDictionary*)DP_mutableDictionaryValueForKey:(NSString*)key {
    return [DPMutableDictionary dictionaryInUserDefaults:self key:key];
}

@end

@implementation DPDictionaryController

-(id)valueForUndefinedKey:(NSString*)key {
    return nil;
}

@end
*/





















