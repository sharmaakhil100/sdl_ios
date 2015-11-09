#import <Quick/Quick.h>
#import <Nimble/Nimble.h>

#import "SDLDeleteFileResponse.h"
#import "SDLError.h"
#import "SDLFile.h"
#import "SDLFileManager.h"
#import "SDLFileType.h"
#import "SDLListFiles.h"
#import "SDLListFilesResponse.h"
#import "SDLNotificationConstants.h"
#import "SDLPutFile.h"
#import "SDLPutFileResponse.h"
#import "SDLRPCResponse.h"
#import "TestConnectionManager.h"


QuickSpecBegin(SDLFileManagerSpec)

describe(@"SDLFileManager", ^{
    __block TestConnectionManager *testConnectionManager = nil;
    __block SDLFileManager *testFileManager = nil;
    
    __block SDLListFilesResponse *testListFilesResponse = nil;
    __block NSArray<NSString *> *testInitialFileNames = nil;
    __block NSNumber *testInitialSpaceAvailable = nil;
    
    beforeEach(^{
        testConnectionManager = [[TestConnectionManager alloc] init];
        testFileManager = [[SDLFileManager alloc] initWithConnectionManager:testConnectionManager];
        
        testInitialFileNames = @[@"testFile1", @"testFile2", @"testFile3"];
        testListFilesResponse = [[SDLListFilesResponse alloc] init];
        testListFilesResponse.spaceAvailable = testInitialSpaceAvailable;
        testListFilesResponse.filenames = [NSMutableArray arrayWithArray:testInitialFileNames];
        [testConnectionManager respondToLastRequestWithResponse:testListFilesResponse];
    });
    
    describe(@"before receiving a connect notification", ^{
        it(@"should be in the not connected state", ^{
            expect(@(testFileManager.state)).to(equal(@(SDLFileManagerStateNotConnected)));
        });
        
        it(@"bytesAvailable should be 0", ^{
            expect(@(testFileManager.bytesAvailable)).to(equal(@0));
        });
        
        it(@"remoteFileNames should be empty", ^{
            expect(testFileManager.remoteFileNames).to(beEmpty());
        });
        
        it(@"allowOverwrite should be YES by default", ^{
            expect(@(testFileManager.allowOverwrite)).to(equal(@YES));
        });
    });
    
    describe(@"after receiving a connect notification", ^{
        beforeEach(^{
            [[NSNotificationCenter defaultCenter] postNotificationName:SDLDidConnectNotification object:nil];
        });
        
        it(@"should have sent the connection manager a ListFiles request", ^{
            expect(testConnectionManager.receivedRequests.lastObject).to(beAnInstanceOf([SDLListFiles class]));
        });
        
        describe(@"before receiving a ListFiles response", ^{
            it(@"should be in the waiting state", ^{
                expect(@(testFileManager.state)).to(equal(@(SDLFileManagerStateWaiting)));
            });
            
            xdescribe(@"entering files before a response then receiving the response", ^{
                it(@"should immediately start sending queued files", ^{
                    
                });
            });
        });
        
        describe(@"after receiving a ListFiles response", ^{
            beforeEach(^{
                [testConnectionManager respondToLastRequestWithResponse:testListFilesResponse];
            });
            
            it(@"should be in the ready state", ^{
                expect(@(testFileManager.state)).to(equal(@(SDLFileManagerStateReady)));
            });
            
            it(@"should properly set the remote file names", ^{
                expect(testFileManager.remoteFileNames).to(equal(testListFilesResponseFileNames));
            });
            
            it(@"should properly set the space available", ^{
                expect(@(testFileManager.bytesAvailable)).to(equal(testListFilesResponseSpaceAvailable));
            });
            
            describe(@"deleting a file", ^{
                __block BOOL completionSuccess = NO;
                __block NSUInteger completionBytesAvailable = 0;
                __block NSError *completionError = nil;
                
                context(@"when the file is unknown", ^{
                    beforeEach(^{
                        NSString *someUnknownFileName = @"Some Unknown File Name";
                        [testFileManager deleteRemoteFileWithName:someUnknownFileName completionHandler:^(BOOL success, NSUInteger bytesAvailable, NSError * _Nullable error) {
                            completionSuccess = success;
                            completionBytesAvailable = bytesAvailable;
                            completionError = error;
                        }];
                    });
                    
                    it(@"should return NO for success", ^{
                        expect(@(completionSuccess)).to(equal(@NO));
                    });
                    
                    it(@"should return 0 for bytesAvailable", ^{
                        expect(@(completionBytesAvailable)).to(equal(@0));
                    });
                    
                    it(@"should return the correct error", ^{
                        expect(completionError).to(equal([NSError sdl_fileManager_noKnownFileError]));
                    });
                    
                    it(@"should still contain all files", ^{
                        expect(testFileManager.remoteFileNames).to(haveCount(@(testListFilesResponseFileNames.count)));
                    });
                });
                
                context(@"when the file is known", ^{
                    __block NSUInteger newSpaceAvailable = 600;
                    __block NSString *someKnownFileName = nil;
                    __block BOOL completionSuccess = NO;
                    __block NSUInteger completionBytesAvailable = 0;
                    __block NSError *completionError = nil;
                    
                    beforeEach(^{
                        someKnownFileName = testListFilesResponseFileNames.firstObject;
                        [testFileManager deleteRemoteFileWithName:someKnownFileName completionHandler:^(BOOL success, NSUInteger bytesAvailable, NSError * _Nullable error) {
                            completionSuccess = success;
                            completionBytesAvailable = bytesAvailable;
                            completionError = error;
                        }];
                        
                        SDLDeleteFileResponse *deleteResponse = [[SDLDeleteFileResponse alloc] init];
                        deleteResponse.spaceAvailable = @(newSpaceAvailable);
                        [testConnectionManager respondToLastRequestWithResponse:deleteResponse];
                    });
                    
                    it(@"should return YES for success", ^{
                        expect(@(completionSuccess)).to(equal(@YES));
                    });
                    
                    it(@"should return correct number of bytesAvailable", ^{
                        expect(@(completionBytesAvailable)).to(equal(@(newSpaceAvailable)));
                    });
                    
                    it(@"should set the new number of bytes to file manager's bytesAvailable property", ^{
                        expect(@(testFileManager.bytesAvailable)).to(equal(@(newSpaceAvailable)));
                    });
                    
                    it(@"should return the correct error", ^{
                        expect(completionError).to(equal(beNil()));
                    });
                });
            });
            
            describe(@"uploading a new file", ^{
                __block NSString *fileNameAlreadyExists = @"testFile1";
                __block SDLFile *testUploadFile = nil;
                __block BOOL completionSuccess = NO;
                __block NSUInteger completionBytesAvailable = 0;
                __block NSError *completionError = nil;
                
                __block SDLPutFile *sentPutFile = nil;
                __block NSData *testFileData = nil;
                __block SDLFileType *testFileType = nil;
                
                context(@"when there is a remote file named the same thing", ^{
                    context(@"when allow overwrite is true", ^{
                        beforeEach(^{
                            testFileType = [SDLFileType BINARY];
                            testFileData = [@"someData" dataUsingEncoding:NSUTF8StringEncoding];
                            testUploadFile = [[SDLFile alloc] initWithData:testFileData name:fileNameAlreadyExists type:testFileType persistent:NO];
                            
                            [testFileManager uploadFile:testUploadFile completionHandler:^(BOOL success, NSUInteger bytesAvailable, NSError * _Nullable error) {
                                completionSuccess = success;
                                completionBytesAvailable = bytesAvailable;
                                completionError = error;
                            }];
                            
                            sentPutFile = (SDLPutFile *)testConnectionManager.receivedRequests.lastObject;
                        });
                        
                        it(@"should set the file manager state to waiting", ^{
                            expect(@(testFileManager.state)).to(equal(@(SDLFileManagerStateWaiting)));
                        });
                        
                        it(@"should create a putfile that is the correct size", ^{
                            expect(sentPutFile.length).to(equal(@(testFileData.length)));
                        });
                        
                        it(@"should create a putfile with the correct data", ^{
                            expect(sentPutFile.bulkData).to(equal(testFileData));
                        });
                        
                        it(@"should create a putfile with the correct file type", ^{
                            expect(sentPutFile.fileType).to(equal(testFileType));
                        });
                        
                        context(@"when the connection returns without error", ^{
                            __block SDLPutFileResponse *testResponse = nil;
                            __block NSNumber *testResponseBytesAvailable = nil;
                            
                            beforeEach(^{
                                testResponse = [[SDLPutFileResponse alloc] init];
                                testResponseBytesAvailable = @750;
                                testResponse.spaceAvailable = testResponseBytesAvailable;
                                
                                [testConnectionManager respondToLastRequestWithResponse:testResponse];
                            });
                            
                            it(@"should set the bytes available correctly", ^{
                                expect(@(testFileManager.bytesAvailable)).to(equal(testResponseBytesAvailable));
                            });
                            
                            it(@"should call the completion handler with the new bytes available", ^{
                                expect(@(completionBytesAvailable)).to(equal(testResponseBytesAvailable));
                            });
                            
                            it(@"should still have the file name available", ^{
                                expect(testFileManager.remoteFileNames).to(contain(fileNameAlreadyExists));
                            });
                            
                            it(@"should call the completion handler with success YES", ^{
                                expect(@(completionSuccess)).to(equal(@YES));
                            });
                            
                            it(@"should call the completion handler with nil error", ^{
                                expect(completionError).to(beNil());
                            });
                            
                            it(@"should set the file manager state to ready", ^{
                                expect(@(testFileManager.state)).to(equal(@(SDLFileManagerStateReady)));
                            });
                        });
                        
                        context(@"when the connection returns NO success", ^{
                            __block SDLPutFileResponse *testResponse = nil;
                            __block NSNumber *testResponseBytesAvailable = nil;
                            
                            beforeEach(^{
                                testResponse = [[SDLPutFileResponse alloc] init];
                                testResponseBytesAvailable = @750;
                                testResponse.spaceAvailable = testResponseBytesAvailable;
                                testResponse.success = @NO;
                                
                                [testConnectionManager respondToLastRequestWithResponse:testResponse];
                            });
                            
                            it(@"should set the bytes available correctly", ^{
                                expect(@(testFileManager.bytesAvailable)).to(equal(testResponseBytesAvailable));
                            });
                            
                            it(@"should call the completion handler with the new bytes available", ^{
                                expect(@(completionBytesAvailable)).to(equal(testResponseBytesAvailable));
                            });
                            
                            it(@"should still have the file name available", ^{
                                expect(testFileManager.remoteFileNames).to(contain(fileNameAlreadyExists));
                            });
                            
                            it(@"should call the completion handler with success YES", ^{
                                expect(@(completionSuccess)).to(equal(@NO));
                            });
                            
                            it(@"should call the completion handler with nil error", ^{
                                expect(completionError).to(beNil());
                            });
                            
                            it(@"should set the file manager state to ready", ^{
                                expect(@(testFileManager.state)).to(equal(@(SDLFileManagerStateReady)));
                            });
                        });
                        
                        context(@"when the connection errors without a response", ^{
                            beforeEach(^{
                                [testConnectionManager respondToLastRequestWithResponse:nil error:[NSError sdl_lifecycle_notReadyError]];
                            });
                            
                            it(@"should not set a new bytes available", ^{
                                expect(@(testFileManager.bytesAvailable)).to(equal(testInitialSpaceAvailable));
                            });
                            
                            it(@"should call the completion handler with the current bytes available", ^{
                                expect(@(completionBytesAvailable)).to(equal(testInitialSpaceAvailable));
                            });
                            
                            it(@"should still have the file name available", ^{
                                expect(testFileManager.remoteFileNames).to(contain(fileNameAlreadyExists));
                            });
                            
                            it(@"should call the completion handler with success NO", ^{
                                expect(@(completionSuccess)).to(equal(@NO));
                            });
                            
                            it(@"should call the completion handler with nil error", ^{
                                expect(completionError).to(equal([NSError sdl_lifecycle_notReadyError]));
                            });
                            
                            it(@"should set the file manager state to ready", ^{
                                expect(@(testFileManager.state)).to(equal(@(SDLFileManagerStateReady)));
                            });
                        });
                    });
                    
                    context(@"when allow overwrite is false", ^{
                        __block SDLRPCRequest *lastRequest = nil;
                        
                        beforeEach(^{
                            testFileManager.allowOverwrite = NO;
                            
                            testFileType = [SDLFileType BINARY];
                            testFileData = [@"someData" dataUsingEncoding:NSUTF8StringEncoding];
                            testUploadFile = [[SDLFile alloc] initWithData:testFileData name:fileNameAlreadyExists type:testFileType persistent:NO];
                            
                            [testFileManager uploadFile:testUploadFile completionHandler:^(BOOL success, NSUInteger bytesAvailable, NSError * _Nullable error) {
                                completionSuccess = success;
                                completionBytesAvailable = bytesAvailable;
                                completionError = error;
                            }];
                            
                            lastRequest = testConnectionManager.receivedRequests.lastObject;
                        });
                        
                        it(@"should not have sent any putfiles", ^{
                            expect(lastRequest).toNot(beAnInstanceOf([SDLPutFile class]));
                        });
                        
                        it(@"should fail", ^{
                            expect(@(completionSuccess)).to(equal(@NO));
                        });
                        
                        it(@"should return the same bytes as the file manager", ^{
                            expect(@(completionBytesAvailable)).to(equal(@(testFileManager.bytesAvailable)));
                        });
                        
                        it(@"should return an error", ^{
                            expect(completionError).to(equal([NSError sdl_fileManager_cannotOverwriteError]));
                        });
                    });
                });
                
                xcontext(@"when there is not a remote file named the same thing", ^{
                    
                });
            });
            
            xdescribe(@"force uploading a file", ^{
                
            });
        });
    });
});

QuickSpecEnd
