/* ********************************************************************* 
                  _____         _               _
                 |_   _|____  _| |_ _   _  __ _| |
                   | |/ _ \ \/ / __| | | |/ _` | |
                   | |  __/>  <| |_| |_| | (_| | |
                   |_|\___/_/\_\\__|\__,_|\__,_|_|

 Copyright (c) 2010 - 2015 Codeux Software, LLC & respective contributors.
        Please see Acknowledgements.pdf for additional information.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of Textual and/or "Codeux Software, LLC", nor the 
      names of its contributors may be used to endorse or promote products 
      derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 SUCH DAMAGE.

 *********************************************************************** */

NS_ASSUME_NONNULL_BEGIN

@implementation TPCPreferencesImportExport

+ (void)importInWindow:(NSWindow *)window
{
	NSParameterAssert(window != nil);

	[TLOPopupPrompts sheetWindowWithWindow:window
									  body:TXTLS(@"Prompts[1124][2]")
									 title:TXTLS(@"Prompts[1124][1]")
							 defaultButton:TXTLS(@"Prompts[1124][3]")
						   alternateButton:TXTLS(@"Prompts[0004]")
							   otherButton:nil
						   completionBlock:^(TLOPopupPromptReturnType buttonClicked, NSAlert *originalAlert, BOOL suppressionResponse) {
							   [TPCPreferencesImportExport importPreflight:buttonClicked];
						   }];
}

+ (void)importPreflight:(TLOPopupPromptReturnType)buttonPressed
{
	if (buttonPressed != TLOPopupPromptReturnPrimaryType) {
		return;
	}

	NSOpenPanel *d = [NSOpenPanel openPanel];

	[d setCanChooseFiles:YES];
	[d setResolvesAliases:YES];
	[d setCanChooseDirectories:NO];
	[d setCanCreateDirectories:NO];
	[d setAllowsMultipleSelection:NO];

	[d beginWithCompletionHandler:^(NSInteger returnCode) {
		if (returnCode == NSModalResponseOK) {
			NSURL *pathURL = d.URLs[0];

			[TPCPreferencesImportExport importPostflight:pathURL];
		}
	}];
}

+ (BOOL)importPostflightBackupPreferences
{
	NSString *sourcePath = NSHomeDirectory();

	NSString *basePath = [NSString stringWithFormat:@"/Textual-importBackup-%@.plist", [NSString stringWithUUID]];

	NSString *backupPath = [sourcePath stringByAppendingPathComponent:basePath];

	return [TPCPreferencesImportExport exportPostflightForPath:backupPath filterJunk:NO];
}

+ (void)importPostflight:(NSURL *)pathURL
{
	XRPerformBlockAsynchronouslyOnMainQueue(^{
		[TPCPreferencesImportExport _importPostflight:pathURL];
	});
}

+ (void)_importPostflight:(NSURL *)pathURL
{
	/* Create a backup of the old configuration */
	if ([TPCPreferencesImportExport importPostflightBackupPreferences] == NO) {
		return;
	}

	/* Begin import */
	NSData *fileContents = [NSData dataWithContentsOfURL:pathURL];

	NSError *parseError = nil;

	NSDictionary *propertyList =
	[NSPropertyListSerialization propertyListWithData:fileContents options:NSPropertyListImmutable format:NULL error:&parseError];

	/* Perform actual import if we have the dictionary. */
	if (propertyList == nil) {
		if (parseError) {
			LogToConsole(@"Import failed: %@", [parseError localizedDescription]);
		}

		return;
	}

	/* The loading screen is a generic way to show something during import */
	[mainWindowLoadingScreen() hideAll:NO];

	[mainWindowLoadingScreen() popLoadingConfigurationView];

	[worldController() setIsImportingConfiguration:YES];

	[mainWindowServerList() beginUpdates];

	/* Import data */
	[TPCPreferencesImportExport importContentsOfDictionary:propertyList reloadPreferences:NO];
	
	/* Do not push the loading screen right away. Add a little delay to give everything
	 a chance to settle down before presenting the changes to the user. */
	[TPCPreferencesImportExport performSelector:@selector(_importPostflightCleanup:) withObject:propertyList.allKeys afterDelay:2.0];
}

+ (void)importContentsOfDictionary:(NSDictionary<NSString *, id> *)aDict
{
	[TPCPreferencesImportExport importContentsOfDictionary:aDict reloadPreferences:YES];
}

+ (void)importContentsOfDictionary:(NSDictionary<NSString *, id> *)aDict reloadPreferences:(BOOL)reloadPreferences
{
	NSParameterAssert(aDict != nil);

	[aDict enumerateKeysAndObjectsUsingBlock:^(NSString *key, id object, BOOL *stop) {
		[TPCPreferencesImportExport import:object withKey:key];
	}];

	if (reloadPreferences) {
		[TPCPreferences performReloadActionForKeys:aDict.allKeys];
	}
}

+ (void)import:(id)object withKey:(NSString *)key
{
	NSParameterAssert(key != nil);

	if ([key isEqual:TPCPreferencesThemeNameDefaultsKey])
	{
		if ([object isKindOfClass:[NSString class]] == NO) {
			return;
		}
		
		[TPCPreferences setThemeNameWithExistenceCheck:object];
	}
	else if ([key isEqual:TPCPreferencesThemeFontNameDefaultsKey])
	{
		if ([object isKindOfClass:[NSString class]] == NO) {
			return;
		}
		
		[TPCPreferences setThemeChannelViewFontNameWithExistenceCheck:object];
	}
	else if ([key isEqual:IRCWorldControllerClientListDefaultsKey])
	{
		if ([object isKindOfClass:[NSArray class]] == NO) {
			return;
		}

		[object enumerateObjectsUsingBlock:^(id object, NSUInteger index, BOOL *stop) {
			[TPCPreferencesImportExport importClientConfiguration:object isImportedFromCloud:NO];
		}];
	}
	else if ([key isEqual:@"World Controller"])
	{
		if ([object isKindOfClass:[NSDictionary class]] == NO) {
			return;
		}

		NSArray<NSDictionary *> *clientList = [object arrayForKey:@"clients"];

		if (clientList) {
			[TPCPreferencesImportExport import:clientList withKey:IRCWorldControllerClientListDefaultsKey];
		}
	}

#if TEXTUAL_BUILT_WITH_ICLOUD_SUPPORT == 1
	else if ([key hasPrefix:IRCWorldControllerCloudClientItemDefaultsKeyPrefix] ||
			 [key hasPrefix:IRCWorldControllerCloudListOfDeletedClientsDefaultsKey])
	{
		; // Ignore key...
	}
#endif

	else
	{
		[RZUserDefaults() setObject:object forKey:key];
	}
}

+ (void)importClientConfiguration:(NSDictionary<NSString *, id> *)config isImportedFromCloud:(BOOL)isImportedFromCloud
{
	NSParameterAssert(config != nil);

	IRCClientConfig *clientConfig = [[IRCClientConfig alloc] initWithDictionary:config];

	IRCClient *client = [worldController() findClientById:clientConfig.itemUUID];

#if TEXTUAL_BUILT_WITH_ICLOUD_SUPPORT == 1
	if (isImportedFromCloud) {
		if (client && client.config.excludedFromCloudSyncing) {
			return;
		}
	}
#endif
		
	if (client) {
		if (isImportedFromCloud) {
			[client updateConfigFromTheCloud:clientConfig];
		} else {
			[client updateConfig:clientConfig];
		}
	} else {
		(void)[worldController() createClient:clientConfig reload:YES];
	}
}

+ (void)importPostflightCleanup:(NSArray<NSString *> *)changedKeys
{
	[TPCPreferences performReloadActionForKeys:changedKeys];

	[mainWindowServerList() endUpdates];

	[worldController() setIsImportingConfiguration:NO];

	(void)[mainWindow() reloadLoadingScreen];
}

#pragma mark -
#pragma mark Export

+ (BOOL)isKeyNameSupposedToBeIgnored:(NSString *)key
{
	return [TPCPreferencesUserDefaults keyIsExcludedFromBeingExported:key];
}

+ (NSDictionary<NSString *, id> *)exportedPreferencesDictionaryForCloud
{
	return [TPCPreferencesImportExport exportedPreferencesDictionary:YES filterDefaults:NO];
}

+ (NSDictionary<NSString *, id> *)exportedPreferencesDictionary
{
	return [TPCPreferencesImportExport exportedPreferencesDictionary:YES filterDefaults:YES];
}

+ (NSDictionary<NSString *, id> *)exportedPreferencesDictionary:(BOOL)filterJunk
{
	return [TPCPreferencesImportExport exportedPreferencesDictionary:filterJunk filterDefaults:filterJunk];
}

+ (NSDictionary<NSString *, id> *)exportedPreferencesDictionary:(BOOL)filterJunk filterDefaults:(BOOL)filterDefaults
{
	NSDictionary *exportedPreferences = [RZUserDefaults() dictionaryRepresentation];

	NSDictionary *argumentsDomain = [[NSUserDefaults standardUserDefaults] volatileDomainForName:NSArgumentDomain];

	NSDictionary *defaultsDomain = nil;

	NSDictionary *globalsDomain = nil;

	if (filterDefaults) {
		defaultsDomain = [TPCPreferences defaultPreferences];
	}

	if (filterJunk) {
		globalsDomain = [[NSUserDefaults standardUserDefaults] persistentDomainForName:NSGlobalDomain];
	}

	NSMutableDictionary<NSString *, id> *finalDictionary = [NSMutableDictionary dictionary];

	[exportedPreferences enumerateKeysAndObjectsUsingBlock:^(id key, id object, BOOL *stop) {
		if (NSObjectsAreEqual(object, argumentsDomain[key])) {
			return;
		}

		if (filterJunk && [TPCPreferencesImportExport isKeyNameSupposedToBeIgnored:key]) {
			return;
		} else if (filterJunk && NSObjectsAreEqual(object, globalsDomain[key])) {
			return;
		} else if (filterDefaults && NSObjectsAreEqual(object, defaultsDomain[key])) {
			return;
		}

		finalDictionary[key] = object;
	}];

	return finalDictionary;
}

+ (void)exportInWindow:(NSWindow *)window
{
	NSParameterAssert(window != nil);

	[TLOPopupPrompts sheetWindowWithWindow:window
									  body:TXTLS(@"Prompts[1123][2]")
									 title:TXTLS(@"Prompts[1123][1]")
							 defaultButton:TXTLS(@"Prompts[1123][3]")
						   alternateButton:TXTLS(@"Prompts[0004]")
							   otherButton:nil
						   completionBlock:^(TLOPopupPromptReturnType buttonClicked, NSAlert *originalAlert, BOOL suppressionResponse) {
							   [TPCPreferencesImportExport exportPreflight:buttonClicked];
						   }];
}

+ (void)exportPreflight:(TLOPopupPromptReturnType)buttonPressed
{
	if (buttonPressed != TLOPopupPromptReturnPrimaryType) {
		return;
	}

	NSSavePanel *d = [NSSavePanel savePanel];

	[d setCanCreateDirectories:YES];

	d.nameFieldStringValue = @"TextualPreferences.plist";

	[d beginWithCompletionHandler:^(NSInteger returnCode) {
		if (returnCode == NSModalResponseOK) {
			NSURL *pathURL = d.URL;

			(void)[TPCPreferencesImportExport exportPostflightForURL:pathURL filterJunk:YES];
		}
	}];
}

+ (BOOL)exportPostflightForPath:(NSString *)path
{
	return [TPCPreferencesImportExport exportPostflightForPath:path filterJunk:YES];
}

+ (BOOL)exportPostflightForURL:(NSURL *)pathURL
{
	return [TPCPreferencesImportExport exportPostflightForURL:pathURL filterJunk:YES];
}

+ (BOOL)exportPostflightForPath:(NSString *)path filterJunk:(BOOL)filterJunk
{
	NSParameterAssert(path != nil);

	NSURL *pathURL = [NSURL fileURLWithPath:path];

	return [TPCPreferencesImportExport exportPostflightForURL:pathURL filterJunk:filterJunk];
}

+ (BOOL)exportPostflightForURL:(NSURL *)pathURL filterJunk:(BOOL)filterJunk
{
	NSParameterAssert(pathURL != nil);

	NSDictionary *exportedPreferences = [TPCPreferencesImportExport exportedPreferencesDictionary:filterJunk];

	/* The export will be saved as binary. Two reasons: 1) Discourages user from
	 trying to tamper with stuff. 2) Smaller, faster. Mostly #1. */
	NSError *parseError = nil;

	NSData *propertyList =
	[NSPropertyListSerialization dataWithPropertyList:exportedPreferences format:NSPropertyListBinaryFormat_v1_0 options:0 error:&parseError];

	if (propertyList == nil) {
		if (parseError) {
			LogToConsole(@"Error Creating Property List: %@", [parseError localizedDescription])
		}

		return NO;
	}

	BOOL writeResult = [propertyList writeToURL:pathURL atomically:YES];

	if (writeResult == NO) {
		LogToConsole(@"Write failed");

		return NO;
	}

	return YES;
}

@end

NS_ASSUME_NONNULL_END
