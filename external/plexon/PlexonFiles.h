/*
 * PlexonFiles.h
 *
 * Copyright (c) 1998-2011 Plexon, Inc, Dallas, Texas 75206
 *     www.plexon.com, support@plexon.com
 *
 * This code is provided as-is, in order to assist Plexon users who wish to 
 * use non-Windows platforms such as Linux. Plexon cannot provide support 
 * specific to any non-Windows platform, system, compiler, etc., nor guarantee 
 * correct operation or performance in such environments.
 *
 * Plexon users are free to modify this code as necessary for their personal 
 * use, but this code is not open-source. Only code downloaded directly from 
 * plexon.com is guaranteed to be the latest version.
 *
 * Modified by Benjamin Kraus (bkraus@bu.edu, ben@benkraus.com)
 * Last Modified: $Date: 2013-06-04 13:21:41 -0400 (Tue, 04 Jun 2013) $
 * $Id: PlexonFiles.h 4886 2013-06-04 17:21:41Z bkraus $
 */

#define PL_SingleWFType         (1)
#define PL_StereotrodeWFType    (2)     /* reserved */
#define PL_TetrodeWFType        (3)     /* reserved */
#define PL_ExtEventType         (4)
#define PL_ADDataType           (5)
#define PL_StrobedExtChannel    (257)
#define PL_StartExtChannel      (258)   /* delineates frames, sent for resume also */
#define PL_StopExtChannel       (259)   /* delineates frames, sent for pause also */
#define PL_Pause                (260)   /* not used */
#define PL_Resume               (261)   /* not used */

#define MAX_WF_LENGTH           (56)
#define MAX_WF_LENGTH_LONG      (120)

/*
 * Plexon .plx File Structure Definitions
 */
#define LATEST_PLX_FILE_VERSION 107

#define PLX_HDR_LAST_SPIKE_CHAN     128     /* max spike channel number with counts in TSCounts and WFCounts arrays */
#define PLX_HDR_LAST_UNIT           4       /* max unit number supported by PL_FileHeader information */
#define PLX_HDR_LAST_EVENT_CHAN     299     /* max digital event number that will be counted in EVCounts */
#define PLX_HDR_FIRST_CONT_CHAN_IDX 300     /* index in EVCounts for analog channel 0 */
#define PLX_HDR_LAST_CONT_CHAN      211     /* max (0-based) analog channel number that has counts in EVCounts, starting at [300] */

/* plx file header (is followed by the DSP channel headers, then event channel headers, then slow channel headers) */
struct PL_FileHeader
{
    unsigned int MagicNumber;   /* = 0x58454c50 */
    int     Version;            /* Version of the data format; determines which data items are valid */
    char    Comment[128];       /* User-supplied comment  */
    int     ADFrequency;        /* Timestamp frequency in hertz */
    int     NumDSPChannels;     /* Number of DSP channel headers in the file */
    int     NumEventChannels;   /* Number of Event channel headers in the file */
    int     NumSlowChannels;    /* Number of A/D channel headers in the file */
    int     NumPointsWave;      /* Number of data points in waveform */
    int     NumPointsPreThr;    /* Number of data points before crossing the threshold */

    int     Year;               /* Time/date when the data was acquired */
    int     Month; 
    int     Day; 
    int     Hour; 
    int     Minute; 
    int     Second; 

    int     FastRead;           /* reserved */
    int     WaveformFreq;       /* waveform sampling rate; ADFrequency above is timestamp freq  */
    double  LastTimestamp;      /* duration of the experimental session, in ticks */
    
    /* The following 6 items are only valid if Version >= 103 */
    char    Trodalness;                 /* 1 for single, 2 for stereotrode, 4 for tetrode */
    char    DataTrodalness;             /* trodalness of the data representation */
    char    BitsPerSpikeSample;         /* ADC resolution for spike waveforms in bits (usually 12) */
    char    BitsPerSlowSample;          /* ADC resolution for slow-channel data in bits (usually 12) */
    unsigned short SpikeMaxMagnitudeMV; /* the zero-to-peak voltage in mV for spike waveform adc values (usually 3000) */
    unsigned short SlowMaxMagnitudeMV;  /* the zero-to-peak voltage in mV for slow-channel waveform adc values (usually 5000) */
    
    /* Only valid if Version >= 105 */
    unsigned short SpikePreAmpGain;     /* usually either 1000 or 500 */

    /* Only valid if Version >= 106 */
    char    AcquiringSoftware[18];      /* name and version of the software that originally created/acquired this data file */
    char    ProcessingSoftware[18];     /* name and version of the software that last processed/saved this data file */

    char    Padding[10];        /* so that this part of the header is 256 bytes */
    
    /*
     * Counters for the number of timestamps and waveforms in each channel and unit.
     * Note that even though there may be more than 4 units on any 
     * channel, these arrays only record the counts for the first 4 units in each channel.
     * Likewise, starting with .plx file format version 107, there may be more than 128 
     * spike channels, but these arrays only record the  
     * counts for the first 128 channels.
     * Channel and unit numbers are 1-based - channel entries at [0] and [129] are 
     * unused, and unit entries at [0] are unsorted.
     */
    int     TSCounts[130][5]; /* number of timestamps[channel][unit] */
    int     WFCounts[130][5]; /* number of waveforms[channel][unit] */

    /* Starting at index 300, this array also records the number of samples for the
     * continuous channels.  Note that since EVCounts has only 512 entries, continuous
     * channels above channel 211 do not have sample counts.
	 */
    int     EVCounts[512];    /* number of timestamps[event_number] */
}; /* 7504 bytes */

struct PL_ChanHeader 
{
    char    Name[32];       /* Name given to the DSP channel */
    char    SIGName[32];    /* Name given to the corresponding SIG channel */
    int     Channel;        /* DSP channel number, 1-based */
    int     WFRate;         /* When MAP is doing waveform rate limiting, this is limit w/f per sec divided by 10 */
    int     SIG;            /* SIG channel associated with this DSP channel 1 - based */
    int     Ref;            /* SIG channel used as a Reference signal, 1- based */
    int     Gain;           /* actual gain divided by SpikePreAmpGain. For pre version 105, actual gain divided by 1000. */
    int     Filter;         /* 0 or 1 */
    int     Threshold;      /* Threshold for spike detection in a/d values */
    int     Method;         /* Method used for sorting units, 1 - boxes, 2 - templates */
    int     NUnits;         /* number of sorted units */
    short   Template[5][64];/* Templates used for template sorting, in a/d values */
    int     Fit[5];         /* Template fit */
    int     SortWidth;      /* how many points to use in template sorting (template only) */
    short   Boxes[5][2][4]; /* the boxes used in boxes sorting */
    int     SortBeg;        /* beginning of the sorting window to use in template sorting (width defined by SortWidth) */
    char    Comment[128];   /* Version >=105 */
    unsigned char SrcId;    /* Version >=106, Omniplex Source ID for this channel */
    unsigned char reserved; /* Version >=106 */
    unsigned short ChanId;  /* Version >=106, Omniplex Channel ID within the source for this channel */
    int     Padding[10];
}; /* 1020 bytes */

struct PL_EventHeader 
{
    char    Name[32];       /* name given to this event */
    int     Channel;        /* event number, 1-based */
    char    Comment[128];   /* Version >=105 */
    unsigned char SrcId;    /* Version >=106, Omniplex Source ID for this channel */
    unsigned char reserved; /* Version >=106 */
    unsigned short ChanId;  /* Version >=106, Omniplex Channel ID within the Source for this channel */
    int     Padding[32];
}; /* 296 bytes */

struct PL_SlowChannelHeader 
{
    char    Name[32];       /* name given to this channel */
    int     Channel;        /* channel number, 0-based */
    int     ADFreq;         /* digitization frequency */
    int     Gain;           /* gain at the adc card */
    int     Enabled;        /* whether this channel is enabled for taking data, 0 or 1 */
    int     PreAmpGain;     /* gain at the preamp */

    /* As of Version 104, this indicates the spike channel (PL_ChanHeader.Channel) of
     * a spike channel corresponding to this continuous data channel. 
     * <=0 means no associated spike channel.
	 */
    int     SpikeChannel;

    char    Comment[128];   /* Version >=105 */
    unsigned char SrcId;    /* Version >=106, Omniplex Source ID for this channel */
    unsigned char reserved; /* Version >=106 */
    unsigned short ChanId;  /* Version >=106, Omniplex Channel ID within the Source for this channel */
    int     Padding[27];
}; /* 296 bytes */

/* The header for the data record used in the datafile (*.plx)
 * This is followed by NumberOfWaveforms*NumberOfWordsInWaveform
 * short integers that represent the waveform(s)
 */
struct PL_DataBlockHeader
{
    short   Type;                       /* Data type; 1=spike, 4=Event, 5=continuous */
    unsigned short   UpperByteOf5ByteTimestamp; /* Upper 8 bits of the 40 bit timestamp */
    unsigned int    TimeStamp;                 /* Lower 32 bits of the 40 bit timestamp */
    short   Channel;                    /* Channel number */
    short   Unit;                       /* Sorted unit number; 0=unsorted */
    short   NumberOfWaveforms;          /* Number of waveforms in the data to folow, usually 0 or 1 */
    short   NumberOfWordsInWaveform;    /* Number of samples per waveform in the data to follow */
}; /* 16 bytes */
