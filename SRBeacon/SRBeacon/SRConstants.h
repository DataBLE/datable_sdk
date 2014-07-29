//
//  SRConstants.h
//  Pods
//
//  Created by cuterabbit on 2/5/14.
//
//

#ifndef Pods_SRConstants_h
#define Pods_SRConstants_h

typedef NS_ENUM(NSInteger, SRGender) {
    SRGenderMale,   //  default
    SRGenderFemale
};

typedef NS_ENUM(NSInteger, SRAction) {
    SRActionNone,
    SRActionText,
    SRActionImage,
    SRActionVideo,
    SRActionTVImage,
    SRActionTVVideo
};

//expire interval for mointering mote : 5 mins
#define MOTE_EXPIRE_INTERVAL 300

#ifdef DEBUG
    #define DLog(...) NSLog(__VA_ARGS__)
#else
    #define DLog(...) /* */
#endif

#ifdef DEBUG
    #define DAssert(condition) assert(condition)
#else
    #define DAssert(condition) /* */
#endif

#endif
