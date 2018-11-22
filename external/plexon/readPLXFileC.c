/*
 * readPLXFileC - A MEX function to read a PLX file (Plexon, Inc.).
 *
 * For detailed help run: readPLXFileC('help')
 *
 * Author: Benjamin Kraus (bkraus@bu.edu, ben@benkraus.com)
 * Last Modified: $Date: 2013-06-04 13:21:41 -0400 (Tue, 04 Jun 2013) $
 * Copyright (c) 2012-2013, Benjamin Kraus
 * $Id: readPLXFileC.c 4886 2013-06-04 17:21:41Z bkraus $
 */

/* TO DO LIST
 * 
 * make function name (readPLXFileC) a MACRO (#define)
 * make ID and revision tags macros
 * move dispversion to a separate file (svnversion.c) for reuse in other code.
 * deal with channel maps more elegantly
 * deal with change in 'NumPointsWave' mid-file, or incorrect header.
 * update 'LastTimeStamp' based on the actual data.
 * update 'Nunits' for each spike channel based on full-read data.
 * separate 'fullread' tally from just copying the header tally, then merge two tally functions.
 * potentially merge the two 'tally' functions, and maybe even the data reading function.
 * flip orientation of the 'Waves', either post-processing or in PLXReader class.
 * separate read data counts from the file data counts.
 * check the number of continuous fragments read, and resize the storage space if necesary.
 * make sure program is robust and won't crash upon reaching channels not mentioned in the header
 * add warning about not using full-read
 * add ability to read a list of record numbers
 * read a list (or range) of datablock numbers? (probably not necessary)
 * in class wrapper, convert a list of timestamps into a list of record numbers
 * add a check for timestamps that are not in order (within a particular channel)
 * help and version should output the revision number to the output, not just text.
 * change fullread to false when reading data, so that the header can't be used again.
 * add check to mexFunction to make sure that 'start' is positive, before converting to uint
 *
 */

#include <mex.h>
#include <string.h>
#include <stdint.h>

#include "PlexonFiles.h"

#define MAX_NUM_UNITS (26)
#define MAX_DBH_WORDS (512)
#define MIN(a,b) (((a)<(b))?(a):(b))
#define MAX(a,b) (((a)>(b))?(a):(b))
#define MAKETS(up,low) ((((UINT64_T)(up))<<32) + (UINT64_T)(low))

#define XSTR(x) #x
#define STR(x) XSTR(x)

#ifdef LASTMODDATE
#define LASTMODDATE_STR STR(LASTMODDATE)
#else
#define LASTMODDATE_STR ("")
#endif
        
#ifdef LASTMODTIME
#define LASTMODTIME_STR STR(LASTMODTIME)
#else
#define LASTMODTIME_STR ("")
#endif

#ifdef NDEBUG
#define DEBUGMODE (false)
#else
#define DEBUGMODE (true)
#endif

int dispversion(bool disp)
{
    int n, revnum;
    char idstr[] = "$Id: readPLXFileC.c 4886 2013-06-04 17:21:41Z bkraus $";
    char revstr[] = "$Revision: 4886 $";
    char yearstr[] = "2012";
    char *revisionstr, *fname, *datestr, *found;
    char lastmoddate[] = LASTMODDATE_STR;
    char lastmodtime[] = LASTMODTIME_STR;
    bool debugmode = DEBUGMODE;
    
    revisionstr = NULL;
    fname = NULL;
    datestr = NULL;
    found = NULL;
    
    /* Extract the revision number from the revision string. */
    if(strlen(revstr) > 13)
    {
        revisionstr = revstr + 11;
        revstr[strlen(revstr)-2] = '\0';
    } else revisionstr = NULL;
    
    /* Look for the revision string in the ID string. */
    
    if(revisionstr != NULL)
    {
        found = strstr(idstr, revisionstr);
        revnum = atol(revisionstr);
    } else
    {
        found = NULL;
        revnum = 0;
    }
    
    if(!disp) return revnum;
    
    if(found != NULL)
    {
        /* Make sure there are enough characters for a file name.
         * "$Id: " + two spaces = 6 characters.
         */
        n = (int)(found-idstr)-6;
        if(n > 0) fname = idstr + 5;
        
        /* Find the date string, assuming there are enough characters.
         * After revision string there is one space, then the date string.
         * After the date string, there are two more spaces, a username, and a $.
         */
        if(strlen(idstr)-(found-idstr)-strlen(revisionstr)-4 >= 20)
        {
            datestr = found+strlen(revisionstr)+1;
            datestr[20] = '\0';
        }
        fname[n] = '\0';
    }
    
    /* First four characters of the date string should be the year. */
    if(datestr != NULL) strncpy(yearstr,datestr,4);
    
    /* Print out the results. */
    /* if(fname != NULL) mexPrintf("%s\n",fname); */
    mexPrintf("Author: Benjamin Kraus (bkraus@bu.edu, ben@benkraus.com)\n"
            "Copyright (c) 2012-%s\n",yearstr);
    
    if(sizeof(lastmoddate) == 11 && sizeof(lastmodtime) == 9) {
        mexPrintf("Last Modified:");
        if(sizeof(lastmoddate) == 11) mexPrintf(" %s",lastmoddate);
        if(sizeof(lastmodtime) ==  9) mexPrintf(" %s",lastmodtime);
        mexPrintf("\n");
    } else if(datestr != NULL) mexPrintf("Last Modified: %s\n",datestr);
    
    if(revisionstr != NULL) mexPrintf("Revision: %s\n",revisionstr);
    else if(strlen(idstr)>7)
    {
        idstr[strlen(idstr)-2] = '\0';
        mexPrintf("Id: %s\n", idstr+5);
    } else mexPrintf("%s\n", idstr);
    
    if(debugmode) mexPrintf("Debugging: Enabled\n");
    
    return revnum;
}

int disphelp()
{
    mexPrintf("\
 readPLXFileC - A MEX function to read a PLX file (Plexon, Inc.).\n\
 \n\
 USAGE:\n\
   plx = readPLXFileC(filename, varargin)\n\
   plx = readPLXFileC('help')\n\
   plx = readPLXFileC('version')\n\
 \n\
 INPUT:\n\
   filename - Name of the PLX file to read.\n\
   varargin - One (or more) of the arguments listed below. Arguments are\n\
              parsed in order, with later arguments overriding earlier\n\
              arguments.\n\
 \n\
 ARGUMENTS:\n\
   'help'           - Display this help information\n\
   'version'        - Display MEX file version information\n\
                      If 'version' occurs as the first input argument,\n\
                      the revision number is returned as the first (and only) output,\n\
                      and the version information is only printed to screen\n\
                      if no ouptut is requested.\n\
                      If 'version' occurs after the first input argument,\n\
                      version information is printed to the screen, but\n\
                      otherwise the function behaves as though 'version' was not present.\n\
   'headers'        - Retrieve only headers (default)\n\
                      (implies 'nospikes','noevents','nocontinuous')\n\
   '[no]fullread'   - Scan the entire file (default = 'nofullread')\n\
                      ('fullread' is implied if anything other than headers are requested)\n\
   '[no]spikes'     - Retrieve (or not) spike timestamps (default = 'nospikes')\n\
                      'nospikes' implies 'nowaves'\n\
   '[no]waves'      - Retrieve (or not) spike waveforms (default = 'nowaves')\n\
                      'waves' implies 'spikes'\n\
   '[not]units'     - Must be followed by a list of units to (not) retrieve\n\
                      0 = unsorted, 1 = unit 'a', 2 = unit 'b', etc.\n\
   '[no]events'     - Retrieve (or not) event data (default = 'noevents')\n\
   '[no]continuous' - Retrieve (or not) continuous data (default = 'no')\n\
   'all'            - Read the entire file\n\
                      (implies 'spikes','waves','events','continuous')\n\
   'range'          - Time range of data to retrieve\n\
   'start'          - Start of time range of data to retrieve\n\
   'stop'           - End of time range of data to retrieve\n\
   'first'          - First data sample to retrieve\n\
   'num'            - Number of data samples to retieve\n\
   'last'           - Last data sample to retrieve\n\
 \n\
 SELECTING CHANNELS:\n\
   'spikes','waves','events', and/or 'continuous' can be followed by a\n\
   numerical array, which is then parsed to determine which channels to\n\
   retrieve. An empty array implies 'no'. If the array is missing,\n\
   then all channels are retrieved.\n\
 \n\
 OUTPUT:\n\
   plx - A structure containing the PLX file data.\n\
\n");

    return dispversion(true);
}

bool verifyPLXStruct(const mxArray *plx)
{
    return (   mxGetFieldNumber(plx,"DataStartLocation")   >=0
            && mxGetFieldNumber(plx,"ADFrequency")         >=0
            && mxGetFieldNumber(plx,"NumPointsWave")       >=0
            && mxGetFieldNumber(plx,"LastTimestamp")       >=0
            && mxGetFieldNumber(plx,"SpikeTimestampCounts")>=0
            && mxGetFieldNumber(plx,"SpikeWaveformCounts") >=0
            && mxGetFieldNumber(plx,"EventCounts")         >=0
            && mxGetFieldNumber(plx,"ContSampleCounts")    >=0
            && mxGetFieldNumber(plx,"ContSampleFragments") >=0
            && mxGetFieldNumber(plx,"SpikeChannels")       >=0
            && mxGetFieldNumber(plx,"EventChannels")       >=0
            && mxGetFieldNumber(plx,"ContinuousChannels")  >=0
            && mxGetFieldNumber(plx,"FullRead")            >=0
            && mxGetFieldNumber(plx,"DataStartLocation")   >=0
            && mxIsDouble(mxGetField(plx, 0, "DataStartLocation"))
            && mxIsDouble(mxGetField(plx, 0, "ADFrequency"))
            && mxIsDouble(mxGetField(plx, 0, "NumPointsWave"))
            && mxIsDouble(mxGetField(plx, 0, "LastTimestamp"))
            && mxIsDouble(mxGetField(plx, 0, "SpikeTimestampCounts"))
            && mxIsDouble(mxGetField(plx, 0, "SpikeWaveformCounts"))
            && mxIsDouble(mxGetField(plx, 0, "EventCounts"))
            && mxIsDouble(mxGetField(plx, 0, "ContSampleCounts"))
            && mxIsDouble(mxGetField(plx, 0, "ContSampleFragments"))
            && mxIsStruct(mxGetField(plx, 0, "SpikeChannels"))
            && mxIsStruct(mxGetField(plx, 0, "EventChannels"))
            && mxIsStruct(mxGetField(plx, 0, "ContinuousChannels"))
            && mxIsLogicalScalar(mxGetField(plx, 0, "FullRead"))
            && mxIsDouble(mxGetField(plx, 0, "FullRead"))
            );
}

int tallyrange(mxArray *datacounts[5], FILE* fp,
        UINT64_T start, UINT64_T stop, int ADFrequency, int *ChanADFreq)
{
    struct PL_DataBlockHeader dbh;
    double *pts, *pwv, *pev, *psl, *psf;
    
    int i, ntw, maxunits, nspchan, nevchan, nslchan;
    unsigned int nbuf;
    UINT64_T ts, *current_ts;
    unsigned int *current_fn;
    
    short buf[MAX_DBH_WORDS];
    
    nspchan = (int)MIN(mxGetN(datacounts[0]),mxGetN(datacounts[1]));
    maxunits = (int)MIN(mxGetM(datacounts[0]),mxGetM(datacounts[1]));
    pts = mxGetPr(datacounts[0]);
    pwv = mxGetPr(datacounts[1]);

    nevchan = (int)mxGetN(datacounts[2]);
    pev = mxGetPr(datacounts[2]);

    nslchan = (int)MIN(mxGetN(datacounts[3]),mxGetN(datacounts[4]));
    psl = mxGetPr(datacounts[3]);
    psf = mxGetPr(datacounts[4]);
    
    current_ts =     (UINT64_T *)mxMalloc(nslchan*sizeof(UINT64_T));
    current_fn = (unsigned int *)mxCalloc(nslchan,sizeof(unsigned int));
    if(nslchan > 0 && (current_ts == NULL || current_fn == NULL)) return 6;
    for(i = 0; i < nslchan; i++) current_ts[i] = -1;

    /* Clear out existing data counts. */
    for(i = 0; i < nspchan*maxunits; i++) { pts[i] = 0; pwv[i] = 0; }
    for(i = 0; i < nevchan; i++) pev[i] = 0;
    for(i = 0; i < nslchan; i++) { psl[i] = 0; psf[i] = 0; }

    if(stop<start) return 0;
    if(fread(&dbh, sizeof(dbh), 1, fp) != 1) return 0;
    while(!feof(fp))
    {
        if(!(dbh.Type == PL_SingleWFType || dbh.Type == PL_ExtEventType
            || dbh.Type == PL_ADDataType)) return 1;

        nbuf = dbh.NumberOfWaveforms * dbh.NumberOfWordsInWaveform;

        if(dbh.Channel < 0) return 2;
        if(dbh.NumberOfWaveforms < 0 || dbh.NumberOfWordsInWaveform < 0
            || nbuf > MAX_DBH_WORDS) return 3;

        ts = MAKETS(dbh.UpperByteOf5ByteTimestamp, dbh.TimeStamp);
        
        /* This now returns '0' instead of '5'. This effectively removes it
         * from the data count, so it isn't read later, rather than crashing.
         */
        if(fread(&buf[0], sizeof(short), nbuf, fp) != nbuf) return 0;
        if(dbh.Type == PL_SingleWFType)
        {
            if(ts >= start && ts <stop)
            {
                /* Spike channel numbers are 1-based, but so is MATLAB.
                 * For now, make channel numbers zero-based.
                 */
                if(dbh.Channel < 1 || dbh.Channel > nspchan) return 2;
                if(dbh.Unit < 0 || dbh.Unit > MAX_NUM_UNITS) return 4;
                pts[(dbh.Channel-1)*maxunits+dbh.Unit]++;
                pwv[(dbh.Channel-1)*maxunits+dbh.Unit] += dbh.NumberOfWaveforms;
            }
        } else if(dbh.Type == PL_ExtEventType)
        {
            if(ts >= start && ts <stop)
            {
                /* Event channel numbers are 1-based, but so is MATLAB.
                 * For now, make channel numbers zero-based.
                 */
                if(dbh.Channel < 1 || dbh.Channel > nevchan) return 2;
                pev[dbh.Channel-1]++;
            }
        } else if(dbh.Type == PL_ADDataType)
        {
            /* Slow channel numbers are 0-based, but MATLAB is 1-based. */
            if(dbh.Channel >= nslchan) return 2;

            /* Check if any part of the continuous wave fragment is within the time window */
            /* End of fragment is given by ts + (nbuf-1)*ADFrequency/ChanADFreq */
            if(((ts*ChanADFreq[dbh.Channel] + (UINT64_T)(nbuf-1)*ADFrequency) >= 
                    (start*ChanADFreq[dbh.Channel]))  && ts < stop)
            {
                /* Check if this is a new fragment, or continuation of previous fragment.
                 * If continuation of previous fragment, then:
                 * (ts - current_ts)/ADFrequency == current_fn/ChanADFreq
                 */
                if((ts - current_ts[dbh.Channel])*ChanADFreq[dbh.Channel]
                        != (UINT64_T)current_fn[dbh.Channel] * ADFrequency)
                {
                    psf[dbh.Channel]++;
                    current_ts[dbh.Channel] = ts;
                    current_fn[dbh.Channel] = nbuf;
                } else current_fn[dbh.Channel] += nbuf;
                
                /* Determine the number of samples within waveform */
                ntw = nbuf;

                if(ts < start)
                    /* Need to do subtraction before division to avoid overflow */
                    ntw = (int)(nbuf*ADFrequency-(start - ts)*ChanADFreq[dbh.Channel])/ADFrequency;
                if((ts*ChanADFreq[dbh.Channel] + (nbuf-1)*ADFrequency) >= 
                    (stop*ChanADFreq[dbh.Channel]))
                    ntw -= (int)(nbuf*ADFrequency+(ts - stop)*ChanADFreq[dbh.Channel])/ADFrequency;
                psl[dbh.Channel] += ntw;
            }
        }
        if(fread(&dbh, sizeof(dbh), 1, fp) != 1) break;
    }
    if(current_ts != NULL) mxFree(current_ts);
    if(current_fn != NULL) mxFree(current_fn);
    
    return 0;
}

int readPLXData(mxArray *plx, FILE* fp, bool readtypes[5], int numchanin[5],
        int *channels[5], UINT64_T start, UINT64_T stop,
        int first, int last, bool switches[5])
{
    /* readtypes, numchanin, channels:
     * 0 = 'spikes', 1 = 'waves', 2 = 'events',
     * 3 = 'continuous, 4 = 'units'
     */
    /* switches:
     * 0 = 'havestart', 1 = 'havestop',
     * 2 = 'havefirst', 3 = 'havelast' */
    mxArray *datacounts[5], *mxptr, *mxptr2;
    UINT8_T  **spikeunits = NULL;
    INT16_T **spikewaves = NULL, **continuous = NULL, **evval = NULL;
    UINT32_T **spikets32 = NULL,  **events32 = NULL,
             **adts32 = NULL, **frags = NULL;
    UINT64_T **spikets64 = NULL,  **events64 = NULL, **adts64 = NULL;
    int i, j, n, m, c, u, npw, nf = 0, retval, maxchans[5];
    int ADFrequency, *ChanADFreq;
    int *totalspikes, *totalwaves, *chanmap[4],
            *numtoread[4], *numread[4];
    UINT64_T lastts;
    double *ptrs[5];
    bool *whichchans[5], b, bigts, nwavewarn = false;
    unsigned int datastart;
    
    struct PL_DataBlockHeader dbh;
    int ntw, ntr, nbuf, current_fn;
    UINT64_T ts, current_ts;
    short buf[MAX_DBH_WORDS];
    
    lastts = (UINT64_T)mxGetScalar(mxGetField(plx, 0, "LastTimestamp"));
    
    bigts = (lastts > UINT32_MAX);
    
    if(!switches[1]) stop = -1;
    
    if(!switches[0]) start = 0;
    else start = MAX(start,0);
    
    datacounts[0] = mxGetField(plx, 0, "SpikeTimestampCounts");
    datacounts[1] = mxGetField(plx, 0, "SpikeWaveformCounts");
    datacounts[2] = mxGetField(plx, 0, "EventCounts");
    datacounts[3] = mxGetField(plx, 0, "ContSampleCounts");
    datacounts[4] = mxGetField(plx, 0, "ContSampleFragments");
    
    /*
     * 0 = 'spikes', 1 = 'waves', 2 = 'events',
     * 3 = 'continuous, 4 = 'units'
     */
    for(i = 0; i < 5; i++)
    {
        if(i < 4) /* For everything except 'units' */
        {
            ptrs[i] = mxGetPr(datacounts[i]);    /* Get a pointer to data counts */
            maxchans[i] = (int)mxGetN(datacounts[i]); /* Get the number of channels. */
            
            numtoread[i] = (int *)mxCalloc(maxchans[i],sizeof(int));
            numread[i]   = (int *)mxCalloc(maxchans[i],sizeof(int));
            if(maxchans[i] > 0 && numtoread[i] == NULL) return 5;
            if(maxchans[i] > 0 && numread[i]   == NULL) return 5;
            
            chanmap[i]   = (int *)mxMalloc(maxchans[i]*sizeof(int));
            if(maxchans[i] > 0 && chanmap[i] == NULL) return 5;
            
            for(j = 0; j < maxchans[i]; j++) chanmap[i][j] = -1;
        } else if(i == 4)
            maxchans[i] = (int)mxGetM(datacounts[0]); /* Get the number of units. */
        /* Create an array to store an indicator of which channels to read. */
        whichchans[i]  = (bool *)mxMalloc(maxchans[i]*sizeof(bool));
        if(maxchans[i] > 0 && whichchans[i] == NULL) return 5;
        
        if(numchanin[i]>0 && channels[i] != NULL) /* If channel information was provided... */
        {
            /* If we are at this line, then specific channels were
             * specified. This means:
             *   For spikes, waves, events, continuous:
             *     'readtypes' should always be 'true'
             *   For units:
             *     'true' = 'units' (only get those listed)
             *     'false' = 'notunits' (don't get those listed)
             */
            b = readtypes[i];
            
            /* Set default for all channels. */
            for(j = 0; j < maxchans[i]; j++) whichchans[i][j] = !b;
            
            /* Go through each channel listed, and update 'whichchans'. */
            for(j = 0; j < numchanin[i]; j++)
            {
                c = channels[i][j];
                /* spikes and events are 1-based, conver to 0-based.
                 * continuous and units are 0-based, so leave them as is.
                 */
                if(i < 3) c--;
                if(c >= 0 && c < maxchans[i]) whichchans[i][c] = b;
            }
        } else
            for(j = 0; j < maxchans[i]; j++)
                /* If we are at this line, then no specific channels were
                 * specified. This means:
                 *   For spikes, waves, events, continuous:
                 *     'true' = get all channels
                 *     'false' = get no channels
                 *   For units:
                 *     'readtypes' should always be 'true' (get all units)
                 */
                whichchans[i][j] = readtypes[i];
    }
    /* Make sure that we read spike and wave channels together. */
    for(i = 0; i < maxchans[0]; i++)
        whichchans[0][i] |= whichchans[1][i];
    
    ptrs[4] = mxGetPr(datacounts[4]); /* Continuous sample fragments */
    
    /* Set new values for 'readtypes' */
    for(i = 0; i < 4; i++)
    {
        readtypes[i] = false;
        for(c = 0; c < maxchans[i]; c++) readtypes[i] |= whichchans[i][c];
    }
    
    /* Determine the channel map, mapping channel number to 'header'
     * At the same time, clear out any existing data storage fields.
     * Also keep track of the AD frequencies on each continuous channel.
     */
    ADFrequency = (int)mxGetScalar(mxGetField(plx, 0, "ADFrequency"));
    ChanADFreq = (int *)mxMalloc(maxchans[3]*sizeof(int));
    if(maxchans[3] > 0 && ChanADFreq == NULL) return 5;
    for(i = 0; i < maxchans[3]; i++) ChanADFreq[i] = ADFrequency;
    for(i = 0; i < 4; i++)
    {
        mxptr = NULL;
        if(i < 2) mxptr = mxGetField(plx, 0, "SpikeChannels");
        else if(i == 2) mxptr = mxGetField(plx, 0, "EventChannels");
        else if(i == 3) mxptr = mxGetField(plx, 0, "ContinuousChannels");
        if(mxptr == NULL || !mxIsStruct(mxptr))
        {
            readtypes[i] = false;
            continue;
        }
        if(mxGetFieldNumber(mxptr,"Channel")>=0)
        {
            for(j = 0; j < mxGetNumberOfElements(mxptr); j++)
            {
                c = (int)mxGetScalar(mxGetField(mxptr,j,"Channel"));
                if(i < 3) c--;
                if(c >= 0 && c < maxchans[i])
                {
                    chanmap[i][c] = j;
                    if(i == 3 && mxGetFieldNumber(mxptr,"ADFrequency") >= 0)
                        ChanADFreq[c] = (int)mxGetScalar(mxGetField(mxptr,j,"ADFrequency"));
                }
                mxDestroyArray(mxGetField(mxptr,j,"Timestamps"));
                mxDestroyArray(mxGetField(mxptr,j,"Units"));
                mxDestroyArray(mxGetField(mxptr,j,"Waves"));
                mxDestroyArray(mxGetField(mxptr,j,"Values"));
                mxDestroyArray(mxGetField(mxptr,j,"Fragments"));
            }
            mxRemoveField(mxptr,mxGetFieldNumber(mxptr,"Timestamps"));
            mxRemoveField(mxptr,mxGetFieldNumber(mxptr,"Units"));
            mxRemoveField(mxptr,mxGetFieldNumber(mxptr,"Waves"));
            mxRemoveField(mxptr,mxGetFieldNumber(mxptr,"Values"));
            mxRemoveField(mxptr,mxGetFieldNumber(mxptr,"Fragments"));
        }
    }
    
    /* If a start or stop was specified, then redo tally for restricted time range. */
    datastart = (unsigned int)mxGetScalar(mxGetField(plx, 0, "DataStartLocation"));
    if(switches[0] || switches[1])
    {
        if(fseek(fp, datastart, SEEK_SET) != 0) return 9;
        retval = tallyrange(datacounts, fp, start, stop, ADFrequency, ChanADFreq);
        if(retval != 0) return 100+retval;
    }
    
    /* Count the total counts for both spikes and waves (ignoring units) */
    totalspikes = (int *)mxCalloc(maxchans[0],sizeof(int));
    totalwaves  = (int *)mxCalloc(maxchans[0],sizeof(int));
    
    if(maxchans[0] > 0 && totalspikes == NULL) return 5;
    if(maxchans[0] > 0 && totalwaves  == NULL) return 5;

    for(c = 0; c < maxchans[0]; c++)
    {
        for(u = 0; u < maxchans[4]; u++)
        {
            if(chanmap[0][c] >= 0 && whichchans[0][c] && whichchans[4][u])
                totalspikes[c] += (int)ptrs[0][c*maxchans[4]+u];
            if(chanmap[0][c] >= 0 && whichchans[1][c] && whichchans[4][u])
                totalwaves[c]  += (int)ptrs[1][c*maxchans[4]+u];
        }
    }
    
    /* Zero out event channels that are not to be read or have no header. */
    for(c = 0; c < maxchans[2]; c++)
        if(chanmap[2][c] < 0 || !whichchans[2][c]) ptrs[2][c] = 0;
    
    /* Zero out continuous channels that are not to be read or have no header. */
    for(c = 0; c < maxchans[3]; c++)
        if(chanmap[3][c] < 0 || !whichchans[3][c]) ptrs[3][c] = 0;
    
    /* Make sure the 'first' is at least 1 */
    if(!switches[2]) first = 1;
    else first = MAX(first,1);
    
    /* Determine how many samples to read from each channel. */
    for(i = 0; i < 4; i++)
    {
        for(c = 0; c < maxchans[i]; c++)
        {
            if(i == 0)
            {
                if(switches[3])
                    numtoread[i][c] = MIN(totalspikes[c]-first+1,last-first+1);
                else numtoread[i][c] = totalspikes[c]-first+1;
            } else if(i == 1)
            {
                if(switches[3])
                    numtoread[i][c] = MIN(totalwaves[c]-first+1,last-first+1);
                else numtoread[i][c] = totalwaves[c]-first+1;
            } else
            {
                j = (int)ptrs[i][c];
                if(switches[3]) numtoread[i][c] = MIN(j-first+1,last-first+1);
                else numtoread[i][c] = j-first+1;
            }
            numtoread[i][c] = MAX(0,numtoread[i][c]);
        }
    }
    
    /* Initialize the storage to hold the spike data that is being read. */
    npw = (int)mxGetScalar(mxGetField(plx, 0, "NumPointsWave"));
    if(readtypes[0] || readtypes[1])
    {
        mxptr = mxGetField(plx, 0, "SpikeChannels");
        
        if(bigts)
        {
            spikets64 = mxCalloc(maxchans[0],sizeof(UINT64_T *));
            if(maxchans[0] > 0 && spikets64 == NULL) return 5;
        } else
        {
            spikets32 = mxCalloc(maxchans[0],sizeof(UINT32_T *));
            if(maxchans[0] > 0 && spikets32 == NULL) return 5;
        }
        
        if(mxAddField(mxptr, "Timestamps") < 0) return 10;
        
        spikeunits = mxCalloc(maxchans[0],sizeof(UINT8_T *));
        if(maxchans[0] > 0 && spikeunits == NULL) return 5;
        if(mxAddField(mxptr, "Units") < 0) return 10;
        
        if(readtypes[1])
        {
            spikewaves = mxCalloc(maxchans[0],sizeof(INT16_T *));
            if(maxchans[0] > 0 && spikewaves == NULL) return 5;
            if(mxAddField(mxptr, "Waves") < 0) return 10;
        }
        
        for(c = 0; c < maxchans[0]; c++)
        {
            if(numtoread[0][c] > 0 && chanmap[0][c] >= 0)
            {
                if(readtypes[1]) n = numtoread[1][c];
                else n = numtoread[0][c];
                if(bigts)
                {
                    spikets64[c] = (UINT64_T *)mxCalloc(n,sizeof(UINT64_T));
                    if(n > 0 && spikets64[c] == NULL) return 510;
                    mxptr2 = mxCreateNumericMatrix(0,0,mxUINT64_CLASS,mxREAL);
                    mxSetData(mxptr2, spikets64[c]);
                } else
                {
                    spikets32[c] = (UINT32_T *)mxCalloc(n,sizeof(UINT32_T));
                    if(n > 0 && spikets32[c] == NULL) return 510;
                    mxptr2 = mxCreateNumericMatrix(0,0,mxUINT32_CLASS,mxREAL);
                    mxSetData(mxptr2, spikets32[c]);
                }
                mxSetM(mxptr2, n); mxSetN(mxptr2, 1);
                mxSetField(mxptr, chanmap[0][c], "Timestamps", mxptr2);
                
                spikeunits[c] = (UINT8_T *)mxCalloc(n,sizeof(UINT8_T));
                if(n > 0 && spikeunits[c] == NULL) return 511;
                mxptr2 = mxCreateNumericMatrix(0,0,mxUINT8_CLASS,mxREAL);
                mxSetData(mxptr2, spikeunits[c]);
                mxSetM(mxptr2, n); mxSetN(mxptr2, 1);
                mxSetField(mxptr, chanmap[0][c], "Units", mxptr2);
                
                if(readtypes[1])
                {
                    spikewaves[c] = (INT16_T *)mxCalloc(npw*n,sizeof(INT16_T));
                    if(npw*n > 0 && spikewaves[c] == NULL) return 512;
                    mxptr2 = mxCreateNumericMatrix(0,0,mxINT16_CLASS,mxREAL);
                    mxSetData(mxptr2, spikewaves[c]);
                    mxSetM(mxptr2, npw); mxSetN(mxptr2, n);
                    mxSetField(mxptr, chanmap[0][c], "Waves", mxptr2);
                }
            } else if(chanmap[0][c] >= 0)
            {
                mxptr2 = mxCreateNumericMatrix(0,1,mxUINT32_CLASS,mxREAL);
                mxSetField(mxptr, chanmap[0][c], "Timestamps", mxptr2);
                
                mxptr2 = mxCreateNumericMatrix(0,1,mxUINT8_CLASS,mxREAL);
                mxSetField(mxptr, chanmap[0][c], "Units", mxptr2);
                
                if(readtypes[1])
                {
                    mxptr2 = mxCreateNumericMatrix(0,0,mxINT16_CLASS,mxREAL);
                    mxSetField(mxptr, chanmap[0][c], "Waves", mxptr2);
                }
            }
        }
    }

    /* Initialize the storage to hold the event data that is being read. */
    if(readtypes[2])
    {
        mxptr = mxGetField(plx, 0, "EventChannels");
        
        if(bigts)
        {
            events64 = mxCalloc(maxchans[2],sizeof(UINT64_T *));
            if(maxchans[2] > 0 && events64 == NULL) return 5;
        } else
        {
            events32 = mxCalloc(maxchans[2],sizeof(UINT32_T *));
            if(maxchans[2] > 0 && events32 == NULL) return 5;
        }
        
        if(mxAddField(mxptr, "Timestamps") < 0) return 10;
        
        evval = mxCalloc(maxchans[2],sizeof(INT16_T *));
        if(maxchans[2] > 0 && evval == NULL) return 5;
        if(mxAddField(mxptr, "Values") < 0) return 10;
        
        for(c = 0; c < maxchans[2]; c++)
        {
            if(numtoread[2][c] > 0 && chanmap[2][c] >= 0)
            {
                if(bigts)
                {
                    events64[c] = (UINT64_T *)mxCalloc(numtoread[2][c],sizeof(UINT64_T));
                    if(numtoread[2][c] > 0 && events64[c] == NULL) return 520;
                    mxptr2 = mxCreateNumericMatrix(0,0,mxUINT64_CLASS,mxREAL);
                    mxSetData(mxptr2, events64[c]);
                } else
                {
                    events32[c] = (UINT32_T *)mxCalloc(numtoread[2][c],sizeof(UINT32_T));
                    if(numtoread[2][c] > 0 && events32[c] == NULL) return 520;
                    mxptr2 = mxCreateNumericMatrix(0,0,mxUINT32_CLASS,mxREAL);
                    mxSetData(mxptr2, events32[c]);
                }
                mxSetM(mxptr2, numtoread[2][c]); mxSetN(mxptr2, 1);
                mxSetField(mxptr, chanmap[2][c], "Timestamps", mxptr2);
                
                evval[c] = (INT16_T *)mxCalloc(numtoread[2][c],sizeof(INT16_T));
                if(numtoread[2][c] > 0 && evval[c] == NULL) return 521;
                mxptr2 = mxCreateNumericMatrix(0,0,mxINT16_CLASS,mxREAL);
                mxSetData(mxptr2, evval[c]);
                mxSetM(mxptr2, numtoread[2][c]); mxSetN(mxptr2, 1);
                mxSetField(mxptr, chanmap[2][c], "Values", mxptr2);
            } else if(chanmap[2][c] >= 0)
            {
                mxptr2 = mxCreateNumericMatrix(0,1,mxUINT32_CLASS,mxREAL);
                mxSetField(mxptr, chanmap[2][c], "Timestamps", mxptr2);
                
                mxptr2 = mxCreateNumericMatrix(0,1,mxINT16_CLASS,mxREAL);
                mxSetField(mxptr, chanmap[2][c], "Values", mxptr2);
            }
        }
    }

    /* Initialize the storage to hold the continuous data that is being read. */
    if(readtypes[3])
    {
        mxptr = mxGetField(plx, 0, "ContinuousChannels");
        
        if(bigts)
        {
            adts64 = mxCalloc(maxchans[3],sizeof(UINT64_T *));
            if(maxchans[3] > 0 && adts64 == NULL) return 5;
        } else
        {
            adts32 = mxCalloc(maxchans[3],sizeof(UINT32_T *));
            if(maxchans[3] > 0 && adts32 == NULL) return 5;
        }
        
        if(mxAddField(mxptr, "Timestamps") < 0) return 10;

        frags = mxCalloc(maxchans[3],sizeof(UINT32_T *));
        if(maxchans[3] > 0 && frags == NULL) return 5;
        if(mxAddField(mxptr, "Fragments") < 0) return 10;
        
        continuous = mxCalloc(maxchans[3],sizeof(INT16_T *));
        if(maxchans[3] > 0 && continuous == NULL) return 5;
        if(mxAddField(mxptr, "Values") < 0) return 10;
        
        for(c = 0; c < maxchans[3]; c++)
        {
            if(numtoread[3][c] > 0 && chanmap[3][c] >= 0)
            {
                /* Create the maximum amount of space necessary for the
                 * fragment timestamps. We will eliminate the unneeded space later.
                 * There is probably a more eligant way to do this. */
                if(bigts)
                {
                    adts64[c] = (UINT64_T *)mxCalloc((int)ptrs[4][c],sizeof(UINT64_T));
                    if(ptrs[4][c] > 0 && adts64[c] == NULL) return 530;
                    mxptr2 = mxCreateNumericMatrix(0,0,mxUINT64_CLASS,mxREAL);
                    mxSetData(mxptr2, adts64[c]);
                } else
                {
                    adts32[c] = (UINT32_T *)mxCalloc((int)ptrs[4][c],sizeof(UINT32_T));
                    if(ptrs[4][c] > 0 && adts32[c] == NULL) return 530;
                    mxptr2 = mxCreateNumericMatrix(0,0,mxUINT32_CLASS,mxREAL);
                    mxSetData(mxptr2, adts32[c]);
                }
                mxSetM(mxptr2, (int)ptrs[4][c]); mxSetN(mxptr2, 1);
                mxSetField(mxptr, chanmap[3][c], "Timestamps", mxptr2);
                
                frags[c] = (UINT32_T *)mxCalloc((int)ptrs[4][c],sizeof(UINT32_T));
                if(ptrs[4][c] > 0 && frags[c] == NULL) return 531;
                mxptr2 = mxCreateNumericMatrix(0,0,mxUINT32_CLASS,mxREAL);
                mxSetData(mxptr2, frags[c]);
                mxSetM(mxptr2, (int)ptrs[4][c]); mxSetN(mxptr2, 1);
                mxSetField(mxptr, chanmap[3][c], "Fragments", mxptr2);
                
                continuous[c] = (INT16_T *)mxCalloc(numtoread[3][c],sizeof(INT16_T));
                if(numtoread[3][c] > 0 && continuous[c] == NULL) return 532;
                mxptr2 = mxCreateNumericMatrix(0,0,mxINT16_CLASS,mxREAL);
                mxSetData(mxptr2, continuous[c]);
                mxSetM(mxptr2, numtoread[3][c]); mxSetN(mxptr2, 1);
                mxSetField(mxptr, chanmap[3][c], "Values", mxptr2);
            } else if(chanmap[3][c] >= 0)
            {
                mxptr2 = mxCreateNumericMatrix(0,1,mxUINT32_CLASS,mxREAL);
                mxSetField(mxptr, chanmap[3][c], "Timestamps", mxptr2);
                
                mxptr2 = mxCreateNumericMatrix(0,1,mxUINT32_CLASS,mxREAL);
                mxSetField(mxptr, chanmap[3][c], "Fragments", mxptr2);
                
                mxptr2 = mxCreateNumericMatrix(0,1,mxINT16_CLASS,mxREAL);
                mxSetField(mxptr, chanmap[3][c], "Values", mxptr2);
            }
        }
    }
    
    /*
     * 0 = 'spikes', 1 = 'waves', 2 = 'events',
     * 3 = 'continuous, 4 = 'units'
     */
    /* Clear out existing data counts. */
    for(c = 0; c < maxchans[0]*maxchans[4]; c++) { ptrs[0][c] = 0; ptrs[1][c] = 0; }
    for(c = 0; c < maxchans[2];             c++)   ptrs[2][c] = 0;
    for(c = 0; c < maxchans[3];             c++) { ptrs[3][c] = 0; ptrs[4][c] = 0; }
    
    /* Stop here if the time span is zero (or negative) */
    if(stop<start) return 0;
    
    /* Rewind back to the start of the data. */
    if(fseek(fp, datastart, SEEK_SET) != 0) return 9;
    
    /* Lets actually read the data now. */
    if(fread(&dbh, sizeof(dbh), 1, fp) != 1) return 0;
    while(!feof(fp))
    {
        if(!(dbh.Type == PL_SingleWFType || dbh.Type == PL_ExtEventType
            || dbh.Type == PL_ADDataType)) return 101;

        nbuf = dbh.NumberOfWaveforms * dbh.NumberOfWordsInWaveform;
        
        if(dbh.Channel < 0) return 102;
        if(dbh.NumberOfWaveforms < 0 || dbh.NumberOfWordsInWaveform < 0
            || nbuf > MAX_DBH_WORDS) return 103;

        /* This now returns '0' instead of '105'. This allows the program
         * to return the data read up to this point, rather than crashing.
         * This warning should be a duplicate of the previous warning, but
         * I'm leaving it in just in case.
         */
        if(fread(&buf[0], sizeof(short), nbuf, fp) != nbuf)
        {
            mexWarnMsgIdAndTxt("readPLXFile:readData:incompleteDataBlock",
                    "Incomplete data block:\n(type: %d, channel: %d, "
                    "timestamp: (%d,%d), offset: 0x%X).\n"
                    "Skipping this and all following data blocks.",
                    dbh.Type, dbh.Channel, dbh.UpperByteOf5ByteTimestamp,
                    dbh.TimeStamp, ftell(fp));
            return 0;
        }
    
        ts = MAKETS(dbh.UpperByteOf5ByteTimestamp, dbh.TimeStamp);
        if(dbh.Type == PL_SingleWFType && readtypes[0] && ts >= start && ts < stop)
        {
            /* Spike channel numbers are 1-based, but so is MATLAB.
             * For now, make channel numbers zero-based.
             */
            if(dbh.Channel < 1 || dbh.Channel > maxchans[0]) return 102;
            if(dbh.Unit < 0 || dbh.Unit >= maxchans[4]) return 104;
            if(readtypes[1] && nbuf > 0 && numtoread[1][dbh.Channel-1] > 0)
            {
                if(dbh.NumberOfWaveforms > 1 && !nwavewarn)
                {
                    if(bigts) mexWarnMsgIdAndTxt("readPLXFile:readData:doubleSpikeBlock",
                            "Spike data block with more than one waveform\n"
                            "(channel: %d, unit: %d, timestamp: (%d,%d), waveforms: %d).\n"
                            "Using same timestamp for all waveforms.",
                            dbh.Channel, dbh.Unit, dbh.UpperByteOf5ByteTimestamp, 
                            dbh.TimeStamp, dbh.NumberOfWaveforms);
                    else mexWarnMsgIdAndTxt("readPLXFile:readData:doubleSpikeBlock",
                            "Spike data block with more than one waveform\n"
                            "(channel: %d, unit: %d, timestamp: %d, waveforms: %d).\n"
                            "Using same timestamp for all waveforms.",
                            dbh.Channel, dbh.Unit, dbh.TimeStamp, dbh.NumberOfWaveforms);
                    nwavewarn = true;
                }
                n = numread[1][dbh.Channel-1]+1-first;
                ntw = MIN(numtoread[1][dbh.Channel-1]-n,dbh.NumberOfWaveforms);
                if(n >= 0 && ntw > 0)
                {
                    for(i = 0; i < ntw; i++)
                    {
                        if(bigts) spikets64[dbh.Channel-1][n+i] = ts;
                        else spikets32[dbh.Channel-1][n+i] = dbh.TimeStamp;
                        spikeunits[dbh.Channel-1][n+i] = (unsigned char)dbh.Unit;
                    }
                    for(i = 0; i < MIN(nbuf,npw*ntw); i++)
                        spikewaves[dbh.Channel-1][n*npw+i] = buf[i];
                    ptrs[0][(dbh.Channel-1)*maxchans[4]+dbh.Unit]++;
                    ptrs[1][(dbh.Channel-1)*maxchans[4]+dbh.Unit]+=ntw;
                }
                numread[0][dbh.Channel-1]++;
                numread[1][dbh.Channel-1] += dbh.NumberOfWaveforms;
            } else if(!readtypes[1] && numtoread[0][dbh.Channel-1] > 0)
            {
                numread[0][dbh.Channel-1]++;
                n = numread[0][dbh.Channel-1]-first;
                if(n >= 0 && n < numtoread[0][dbh.Channel-1])
                {
                    if(bigts) spikets64[dbh.Channel-1][n] = ts;
                    else spikets32[dbh.Channel-1][n] = dbh.TimeStamp;
                    spikeunits[dbh.Channel-1][n] = (unsigned char)dbh.Unit;
                    ptrs[0][(dbh.Channel-1)*maxchans[4]+dbh.Unit]++;
                }
            }
        } else if(dbh.Type == PL_ExtEventType && readtypes[2] && ts >= start && ts < stop)
        {
            /* Event channel numbers are 1-based, but so is MATLAB.
             * For now, make channel numbers zero-based.
             */
            if(dbh.Channel < 1 || dbh.Channel > maxchans[2]) return 102;
            numread[2][dbh.Channel-1]++;
            n = numread[2][dbh.Channel-1]-first;
            if(n >= 0 && n < numtoread[2][dbh.Channel-1])
            {
                if(bigts) events64[dbh.Channel-1][n] = ts;
                else events32[dbh.Channel-1][n] = dbh.TimeStamp;
                evval[dbh.Channel-1][n] = dbh.Unit;
                ptrs[2][dbh.Channel-1]++;
            }
        } else if(dbh.Type == PL_ADDataType && readtypes[3])
        {
            /* Slow channel numbers are 0-based, but MATLAB is 1-based. */
            if(dbh.Channel >= maxchans[3]) return 102;

            /* Check if any part of the continuous wave fragment is within the time window */
            /* End of fragment is given by ts + (nbuf-1)*ADFrequency/ChanADFreq */
            if(numtoread[3][dbh.Channel] > 0 && nbuf > 0 &&
                    ((ts*ChanADFreq[dbh.Channel] + (UINT64_T)(nbuf-1)*ADFrequency) >= 
                    (start*ChanADFreq[dbh.Channel]))  && ts < stop)
            {
                /* Determine the number of samples within time window */
                ntw = nbuf;
                m = 0;
                
                if(ts < start)
                {
                    /* Need to do subtraction before division to avoid rounding and overflow */
                    ntw = (int)(nbuf*ADFrequency-(start - ts)*ChanADFreq[dbh.Channel])/ADFrequency;
                    m = (nbuf-ntw);
                    ts += m*ADFrequency/ChanADFreq[dbh.Channel];
                }
                if((ts*ChanADFreq[dbh.Channel] + (ntw-1)*ADFrequency) >= 
                    (stop*ChanADFreq[dbh.Channel]))
                    ntw -= (int)(ntw*ADFrequency+(ts - stop)*ChanADFreq[dbh.Channel])/ADFrequency;
                
                n = numread[3][dbh.Channel]-first+1;
                if(n+ntw > 0 && n < numtoread[3][dbh.Channel])
                {
                    ntr = ntw;
                    if(n < 0)
                    {
                        ntr += n;
                        m -= n;
                        ts -= n*ADFrequency/ChanADFreq[dbh.Channel];
                        n = 0;
                    }
                    if(n+ntr > numtoread[3][dbh.Channel])
                        ntr = numtoread[3][dbh.Channel] - n;

                    /* Check if this is a new fragment, or continuation of previous fragment.
                     * If continuation of previous fragment, then:
                     * (ts - current_ts)/ADFrequency == current_fn/ChanADFreq
                     */
                    nf = (int)ptrs[4][dbh.Channel]-1;
                    if(nf >= 0)
                    {
                        if(bigts) current_ts = adts64[dbh.Channel][nf];
                        else      current_ts = adts32[dbh.Channel][nf];
                        current_fn = frags[dbh.Channel][nf];
                    }
                    if(nf < 0 || (ts - current_ts)*ChanADFreq[dbh.Channel]
                            != (UINT64_T)current_fn * ADFrequency)
                    {
                        nf = (int)ptrs[4][dbh.Channel]++;
                        if(bigts) adts64[dbh.Channel][nf] = ts;
                        else adts32[dbh.Channel][nf] = (unsigned int)ts;
                        frags[dbh.Channel][nf] = ntr;
                    } else frags[dbh.Channel][nf] += ntr;

                    for(i = 0; i < MIN(ntr,nbuf-m); i++)
                        continuous[dbh.Channel][n+i] = buf[m+i];
                    ptrs[3][dbh.Channel] += ntr;
                }
                numread[3][dbh.Channel] += ntw;
            }
        }
        if(fread(&dbh, sizeof(dbh), 1, fp) != 1) break;
    }
    
    /* Clear memory used */
    for(i = 0; i < 4; i++)
    {
        if(whichchans[i] != NULL) mxFree(whichchans[i]);
        if(numtoread[i]  != NULL) mxFree(numtoread[i]);
        if(numread[i]    != NULL) mxFree(numread[i]);
        if(chanmap[i]    != NULL) mxFree(chanmap[i]);
    }
    
    if(whichchans[4] != NULL) mxFree(whichchans[4]);
    if(totalspikes   != NULL) mxFree(totalspikes);
    if(totalwaves    != NULL) mxFree(totalwaves);
    if(ChanADFreq    != NULL) mxFree(ChanADFreq);

    if(spikets32  != NULL) mxFree(spikets32);
    if(spikets64  != NULL) mxFree(spikets64);
    if(events32   != NULL) mxFree(events32);
    if(events64   != NULL) mxFree(events64);
    if(adts32     != NULL) mxFree(adts32);
    if(adts64     != NULL) mxFree(adts64);

    if(spikeunits != NULL) mxFree(spikeunits);
    if(spikewaves != NULL) mxFree(spikewaves);
    if(continuous != NULL) mxFree(continuous);
    if(evval      != NULL) mxFree(evval);
    if(frags      != NULL) mxFree(frags);
            
    return 0;
}

int tally(mxArray *datacounts[5], FILE* fp, struct PL_FileHeader fh,
    int maxchans[3], bool fullread, int ADFrequency, int *ChanADFreq)
{
    struct PL_DataBlockHeader dbh;
    double *pts, *pwv, *pev, *psl, *psf;
    
    int i, j, maxunits, nspchan, nevchan, nslchan;
    unsigned int nbuf;
    UINT64_T ts, *current_ts;
    unsigned int *current_fn;
    
    short buf[MAX_DBH_WORDS];
    
    if(fullread)
    {
        maxunits = MAX_NUM_UNITS+1;
        
        nspchan = maxchans[0];
        datacounts[0] = mxCreateNumericMatrix(maxunits, nspchan, mxDOUBLE_CLASS, mxREAL);
        pts = mxGetPr(datacounts[0]);
        
        datacounts[1] = mxCreateNumericMatrix(maxunits, nspchan, mxDOUBLE_CLASS, mxREAL);
        pwv = mxGetPr(datacounts[1]);

        nevchan = maxchans[1];
        datacounts[2] = mxCreateNumericMatrix(1, nevchan, mxDOUBLE_CLASS, mxREAL);
        pev = mxGetPr(datacounts[2]);
        
        nslchan = maxchans[2]+1;
        datacounts[3] = mxCreateNumericMatrix(1, nslchan, mxDOUBLE_CLASS, mxREAL);
        psl = mxGetPr(datacounts[3]);
        
        datacounts[4] = mxCreateNumericMatrix(1, nslchan, mxDOUBLE_CLASS, mxREAL);
        psf = mxGetPr(datacounts[4]);
        
        current_ts =     (UINT64_T *)mxMalloc(nslchan*sizeof(UINT64_T));
        current_fn = (unsigned int *)mxCalloc(nslchan,sizeof(unsigned int));
        if(nslchan > 0 && (current_ts == NULL || current_fn == NULL)) return 6;
        for(i = 0; i < nslchan; i++) current_ts[i] = -1;
        
        if(fread(&dbh, sizeof(dbh), 1, fp) != 1) return 0;
        while(!feof(fp))
        {
            if(!(dbh.Type == PL_SingleWFType || dbh.Type == PL_ExtEventType
                || dbh.Type == PL_ADDataType)) return 1;

            nbuf = dbh.NumberOfWaveforms * dbh.NumberOfWordsInWaveform;

            if(dbh.Channel < 0) return 2;
            if(dbh.NumberOfWaveforms < 0 || dbh.NumberOfWordsInWaveform < 0
                || nbuf > MAX_DBH_WORDS) return 3;

            if(fread(&buf[0], sizeof(short), nbuf, fp) != nbuf) 
            {
                /* This now returns '0' instead of '5'. This effectively 
                 * removes it from the data count, so it isn't read later,
                 * rather than crashing.
                 */
                mexWarnMsgIdAndTxt("readPLXFile:tally:incompleteDataBlock",
                        "Incomplete data block:\n(type: %d, channel: %d, "
                        "timestamp: (%d,%d), offset: 0x%X).\n"
                        "Ignoring this and all following data blocks.",
                        dbh.Type, dbh.Channel, dbh.UpperByteOf5ByteTimestamp,
                        dbh.TimeStamp, ftell(fp));
                return 0;
            }
            if(dbh.Type == PL_SingleWFType)
            {
                /* Spike channel numbers are 1-based, but so is MATLAB.
                 * For now, make channel numbers zero-based.
                 */
                if(dbh.Channel < 1 || dbh.Channel > nspchan) return 2;
                if(dbh.Unit < 0 || dbh.Unit > MAX_NUM_UNITS) return 4;
                pts[(dbh.Channel-1)*maxunits+dbh.Unit]++;
                pwv[(dbh.Channel-1)*maxunits+dbh.Unit] += dbh.NumberOfWaveforms;
            } else if(dbh.Type == PL_ExtEventType)
            {
                /* Event channel numbers are 1-based, but so is MATLAB.
                 * For now, make channel numbers zero-based.
                 */
                if(dbh.Channel < 1 || dbh.Channel > nevchan) return 2;
                pev[dbh.Channel-1]++;
            } else if(dbh.Type == PL_ADDataType)
            {
                /* Slow channel numbers are 0-based, but MATLAB is 1-based. */
                if(dbh.Channel >= nslchan) return 2;
                
                /* Check if this is a new fragment, or continuation of previous fragment.
                 * If continuation of previous fragment, then:
                 * (ts - current_ts)/ADFrequency == current_fn/ChanADFreq
                 */
                ts = MAKETS(dbh.UpperByteOf5ByteTimestamp, dbh.TimeStamp);
                if((ts - current_ts[dbh.Channel])*ChanADFreq[dbh.Channel]
                        != (UINT64_T)current_fn[dbh.Channel] * ADFrequency)
                {
                    psf[dbh.Channel]++;
                    current_ts[dbh.Channel] = ts;
                    current_fn[dbh.Channel] = nbuf;
                } else current_fn[dbh.Channel] += nbuf;
                psl[dbh.Channel] += nbuf;
            }
            if(fread(&dbh, sizeof(dbh), 1, fp) != 1) break;
        }
        if(current_ts != NULL) mxFree(current_ts);
        if(current_fn != NULL) mxFree(current_fn);
    } else
    {
        maxunits = PLX_HDR_LAST_UNIT+1;
        
        nspchan = MIN(PLX_HDR_LAST_SPIKE_CHAN, maxchans[0]);
        datacounts[0] = mxCreateNumericMatrix(maxunits, nspchan, mxDOUBLE_CLASS, mxREAL);
        pts = mxGetPr(datacounts[0]);
        
        datacounts[1] = mxCreateNumericMatrix(maxunits, nspchan, mxDOUBLE_CLASS, mxREAL);
        pwv = mxGetPr(datacounts[1]);

        /* Spike channel numbers are 1-based, but so is MATLAB.
         * For now, make channel numbers zero-based.
         */
        for(i = 0; i < maxunits; i++)
            for(j = 0; j < nspchan; j++)
            {
                pts[j*maxunits+i] = fh.TSCounts[j+1][i];
                pwv[j*maxunits+i] = fh.WFCounts[j+1][i];
            }
        
        nevchan = MIN(PLX_HDR_LAST_EVENT_CHAN, maxchans[1]);
        datacounts[2] = mxCreateNumericMatrix(1, nevchan, mxDOUBLE_CLASS, mxREAL);
        pev = mxGetPr(datacounts[2]);
        
        /* Event channel numbers are 1-based, but so is MATLAB.
         * For now, make channel numbers zero-based.
         */
        for(i = 1; i <= nevchan; i++) pev[i-1] = fh.EVCounts[i];
        
        nslchan = MIN(PLX_HDR_LAST_CONT_CHAN+1, maxchans[2]+1);
        datacounts[3] = mxCreateNumericMatrix(1, nslchan, mxDOUBLE_CLASS, mxREAL);
        psl = mxGetPr(datacounts[3]);
        
        /* Slow channel numbers are 0-based, but MATLAB is 1-based. */
        for(i = 0; i < nslchan; i++)
            psl[i] = fh.EVCounts[PLX_HDR_FIRST_CONT_CHAN_IDX+i];
            
        datacounts[4] = mxCreateNumericMatrix(0, 0, mxDOUBLE_CLASS, mxREAL);
    }
    return 0;
}

int buildFileHeadStruct(mxArray *plx, struct PL_FileHeader fh)
{
    mxArray *ma1, *ma2;
    double *p1;
    
    if(    mxAddField(plx, "Version")             < 0
        || mxAddField(plx, "Comment")             < 0
        || mxAddField(plx, "Date")                < 0
        || mxAddField(plx, "NumSpikeChannels")    < 0
        || mxAddField(plx, "NumEventChannels")    < 0
        || mxAddField(plx, "NumContChannels")     < 0
        || mxAddField(plx, "ADFrequency")         < 0
        || mxAddField(plx, "NumPointsWave")       < 0
        || mxAddField(plx, "NumPointsPreThr")     < 0
        || mxAddField(plx, "FastRead")            < 0
        || mxAddField(plx, "WaveformFreq")        < 0
        || mxAddField(plx, "LastTimestamp")       < 0
        || mxAddField(plx, "Trodalness")          < 0
        || mxAddField(plx, "DataTrodalness")      < 0
        || mxAddField(plx, "BitsPerSpikeSample")  < 0
        || mxAddField(plx, "BitsPerContSample")   < 0
        || mxAddField(plx, "SpikeMaxMagnitudeMV") < 0
        || mxAddField(plx, "ContMaxMagnitudeMV")  < 0
        || mxAddField(plx, "SpikePreAmpGain")     < 0
        || mxAddField(plx, "AcquiringSoftware")   < 0
        || mxAddField(plx, "ProcessingSoftware")  < 0
        ) return 1;
    
    mxSetField(plx, 0, "Version", mxCreateDoubleScalar(fh.Version));
    mxSetField(plx, 0, "Comment", mxCreateString(fh.Comment));
    mxSetField(plx, 0, "ADFrequency", mxCreateDoubleScalar(fh.ADFrequency));
    mxSetField(plx, 0, "NumSpikeChannels", mxCreateDoubleScalar(fh.NumDSPChannels));
    mxSetField(plx, 0, "NumEventChannels", mxCreateDoubleScalar(fh.NumEventChannels));
    mxSetField(plx, 0, "NumContChannels", mxCreateDoubleScalar(fh.NumSlowChannels));
    mxSetField(plx, 0, "NumPointsWave", mxCreateDoubleScalar(fh.NumPointsWave));
    mxSetField(plx, 0, "NumPointsPreThr", mxCreateDoubleScalar(fh.NumPointsPreThr));
    mxSetField(plx, 0, "FastRead", mxCreateDoubleScalar(fh.FastRead));
    mxSetField(plx, 0, "WaveformFreq", mxCreateDoubleScalar(fh.WaveformFreq));
    mxSetField(plx, 0, "LastTimestamp", mxCreateDoubleScalar(fh.LastTimestamp));
    
    if(fh.Version >= 103)
    {
        mxSetField(plx, 0, "Trodalness", mxCreateDoubleScalar(fh.Trodalness));
        mxSetField(plx, 0, "DataTrodalness", mxCreateDoubleScalar(fh.DataTrodalness));
        mxSetField(plx, 0, "BitsPerSpikeSample", mxCreateDoubleScalar(fh.BitsPerSpikeSample));
        mxSetField(plx, 0, "BitsPerContSample", mxCreateDoubleScalar(fh.BitsPerSlowSample));
        mxSetField(plx, 0, "SpikeMaxMagnitudeMV", mxCreateDoubleScalar(fh.SpikeMaxMagnitudeMV));
        mxSetField(plx, 0, "ContMaxMagnitudeMV", mxCreateDoubleScalar(fh.SlowMaxMagnitudeMV));
    } else
    {
        mxSetField(plx, 0, "Trodalness", mxCreateDoubleScalar(1));
        mxSetField(plx, 0, "DataTrodalness", mxCreateDoubleScalar(1));
        mxSetField(plx, 0, "BitsPerSpikeSample", mxCreateDoubleScalar(12));
        mxSetField(plx, 0, "BitsPerContSample", mxCreateDoubleScalar(12));
        mxSetField(plx, 0, "SpikeMaxMagnitudeMV", mxCreateDoubleScalar(3000));
        mxSetField(plx, 0, "ContMaxMagnitudeMV", mxCreateDoubleScalar(5000));
    }

    if(fh.Version >= 105) mxSetField(plx, 0, "SpikePreAmpGain", mxCreateDoubleScalar(fh.SpikePreAmpGain));
    else mxSetField(plx, 0, "SpikePreAmpGain", mxCreateDoubleScalar(fh.SpikePreAmpGain));

    if(fh.Version >= 106)
    {
        mxSetField(plx, 0, "AcquiringSoftware", mxCreateString(fh.AcquiringSoftware));
        mxSetField(plx, 0, "ProcessingSoftware", mxCreateString(fh.ProcessingSoftware));
    } else
    {
        mxSetField(plx, 0, "AcquiringSoftware", mxCreateString(""));
        mxSetField(plx, 0, "ProcessingSoftware", mxCreateString(""));
    }

    /* Convert file header date into MATLAB datenum */
    ma1 = mxCreateNumericMatrix(1, 6, mxDOUBLE_CLASS, mxREAL);
    p1 = mxGetPr(ma1);
    
    p1[0] = fh.Year;    p1[1] = fh.Month;   p1[2] = fh.Day;
    p1[3] = fh.Hour;    p1[4] = fh.Minute;  p1[5] = fh.Second;
    
    if(mexCallMATLAB(1, &ma2, 1, &ma1, "datenum") != 0) return 2; /* Error in date */
    mxDestroyArray(ma1);
    
    mxSetField(plx, 0, "Date", ma2);

    return 0;
}

int buildChanHeadStruct(mxArray *plx, struct PL_ChanHeader *ch, int ver, int nchans)
{
    int i, j, k, m;
    mxArray *mach, *ma;
    double *p;
    mwSize boxsz[] = {5, 2, 4};
    
    mach = mxCreateStructMatrix(nchans, 1, 0, NULL);
    
    if(mxAddField(plx, "SpikeChannels") < 0) return 3;
    mxSetField(plx, 0, "SpikeChannels", mach);
    
    if(    mxAddField(mach, "Name")     < 0 || mxAddField(mach, "Channel")    < 0
        || mxAddField(mach, "SIGName")  < 0 || mxAddField(mach, "SIG")        < 0
        || mxAddField(mach, "SourceID") < 0 || mxAddField(mach, "ChannelID")  < 0
        || mxAddField(mach, "Comment")  < 0 || mxAddField(mach, "NUnits")     < 0
        || mxAddField(mach, "Ref")      < 0 || mxAddField(mach, "Filter")     < 0
        || mxAddField(mach, "Gain")     < 0 || mxAddField(mach, "Threshold")  < 0
        || mxAddField(mach, "WFRate")   < 0 || mxAddField(mach, "SortMethod") < 0
        || mxAddField(mach, "SortBeg")  < 0 || mxAddField(mach, "SortWidth")  < 0
        || mxAddField(mach, "Template") < 0 || mxAddField(mach, "Boxes")      < 0
        || mxAddField(mach, "Fit") < 0) return 4;
    
    for (i = 0; i < nchans; i++)
    {
        mxSetField(mach, i, "Name", mxCreateString(ch[i].Name));
        mxSetField(mach, i, "Channel", mxCreateDoubleScalar(ch[i].Channel));
        mxSetField(mach, i, "SIGName", mxCreateString(ch[i].SIGName));
        mxSetField(mach, i, "SIG", mxCreateDoubleScalar(ch[i].SIG));
        mxSetField(mach, i, "NUnits", mxCreateDoubleScalar(ch[i].NUnits));
        mxSetField(mach, i, "Ref", mxCreateDoubleScalar(ch[i].Ref));
        mxSetField(mach, i, "Filter", mxCreateDoubleScalar(ch[i].Filter));
        mxSetField(mach, i, "Gain", mxCreateDoubleScalar(ch[i].Gain));
        mxSetField(mach, i, "Threshold", mxCreateDoubleScalar(ch[i].Threshold));
        mxSetField(mach, i, "WFRate", mxCreateDoubleScalar(ch[i].WFRate));
        mxSetField(mach, i, "SortMethod", mxCreateDoubleScalar(ch[i].Method));
        mxSetField(mach, i, "SortBeg", mxCreateDoubleScalar(ch[i].SortBeg));
        mxSetField(mach, i, "SortWidth", mxCreateDoubleScalar(ch[i].SortWidth));
        
        if(ver >= 105) mxSetField(mach, i, "Comment", mxCreateString(ch[i].Comment));
        else mxSetField(mach, i, "Comment", mxCreateString(""));
        
        if(ver >= 106)
        {
            mxSetField(mach, i, "SourceID", mxCreateDoubleScalar(ch[i].SrcId));
            mxSetField(mach, i, "ChannelID", mxCreateDoubleScalar(ch[i].ChanId));
        } else
        {
            mxSetField(mach, i, "SourceID", mxCreateDoubleScalar(0));
            mxSetField(mach, i, "ChannelID", mxCreateDoubleScalar(0));
        }
        
        /* Copy the template into an mxArray */
        ma = mxCreateNumericMatrix(5, 64, mxDOUBLE_CLASS, mxREAL);
        p = mxGetPr(ma);
        for(j = 0; j < 5; j++) for(k = 0; k < 64; k++) p[k*5+j] = ch[i].Template[j][k];
        
        mxSetField(mach, i, "Template", ma);
        
        /* Copy the fit into an mxArray */
        ma = mxCreateNumericMatrix(5, 1, mxDOUBLE_CLASS, mxREAL);
        p = mxGetPr(ma);
        for(j = 0; j < 5; j++) p[j] = ch[i].Fit[j];
        
        mxSetField(mach, i, "Fit", ma);
        
        /* Copy the boxes into an mxArray */
        ma = mxCreateNumericArray(3, boxsz, mxDOUBLE_CLASS, mxREAL);
        p = mxGetPr(ma);
        for(j = 0; j < 5; j++) for(k = 0; k < 2; k++) for(m = 0; m < 4; m++)
            p[m*10+k*5+j] = ch[i].Boxes[j][k][m];
        
        mxSetField(mach, i, "Boxes", ma);
    }

    return 0;
}

int buildEventHeadStruct(mxArray *plx, struct PL_EventHeader *eh, int ver, int nchans)
{
    int i;
    mxArray *mach;
    
    mach = mxCreateStructMatrix(nchans, 1, 0, NULL);
    
    if(mxAddField(plx, "EventChannels") < 0) return 5;
    mxSetField(plx, 0, "EventChannels", mach);
    
    if(    mxAddField(mach, "Name")      < 0
        || mxAddField(mach, "Channel")   < 0
        || mxAddField(mach, "SourceID")  < 0
        || mxAddField(mach, "ChannelID") < 0
        || mxAddField(mach, "Comment")   < 0) return 6;
    
    for (i = 0; i < nchans; i++)
    {
        mxSetField(mach, i, "Name", mxCreateString(eh[i].Name));
        mxSetField(mach, i, "Channel", mxCreateDoubleScalar(eh[i].Channel));
        
        if(ver >= 105) mxSetField(mach, i, "Comment", mxCreateString(eh[i].Comment));
        else mxSetField(mach, i, "Comment", mxCreateString(""));
        
        if(ver >= 106)
        {
            mxSetField(mach, i, "SourceID", mxCreateDoubleScalar(eh[i].SrcId));
            mxSetField(mach, i, "ChannelID", mxCreateDoubleScalar(eh[i].ChanId));
        } else
        {
            mxSetField(mach, i, "SourceID", mxCreateDoubleScalar(0));
            mxSetField(mach, i, "ChannelID", mxCreateDoubleScalar(0));
        }
    }
    
    return 0;
}

int buildSlowHeadStruct(mxArray *plx, struct PL_SlowChannelHeader *sh, int ver, int nchans)
{
    int i;
    mxArray *mach;
    
    mach = mxCreateStructMatrix(nchans, 1, 0, NULL);
    
    if(mxAddField(plx, "ContinuousChannels") < 0) return 7;
    mxSetField(plx, 0, "ContinuousChannels", mach);
    
    if(    mxAddField(mach, "Name")         < 0
        || mxAddField(mach, "Channel")      < 0
        || mxAddField(mach, "SpikeChannel") < 0
        || mxAddField(mach, "SourceID")     < 0
        || mxAddField(mach, "ChannelID")    < 0
        || mxAddField(mach, "Comment")      < 0
        || mxAddField(mach, "Enabled")      < 0
        || mxAddField(mach, "ADFrequency")  < 0
        || mxAddField(mach, "ADGain")       < 0
        || mxAddField(mach, "PreAmpGain")   < 0
        ) return 8;
    
    for (i = 0; i < nchans; i++)
    {
        mxSetField(mach, i, "Name", mxCreateString(sh[i].Name));
        mxSetField(mach, i, "Channel", mxCreateDoubleScalar(sh[i].Channel));
        mxSetField(mach, i, "Enabled", mxCreateDoubleScalar(sh[i].Enabled));
        mxSetField(mach, i, "ADFrequency", mxCreateDoubleScalar(sh[i].ADFreq));
        mxSetField(mach, i, "ADGain", mxCreateDoubleScalar(sh[i].Gain));
        mxSetField(mach, i, "PreAmpGain", mxCreateDoubleScalar(sh[i].PreAmpGain));
        
        if(ver >= 104) mxSetField(mach, i, "SpikeChannel", mxCreateDoubleScalar(sh[i].SpikeChannel));
        else mxSetField(mach, i, "SpikeChannel", mxCreateDoubleScalar(0));
        
        if(ver >= 105) mxSetField(mach, i, "Comment", mxCreateString(sh[i].Comment));
        else mxSetField(mach, i, "Comment", mxCreateString(""));
        
        if(ver >= 106)
        {
            mxSetField(mach, i, "SourceID", mxCreateDoubleScalar(sh[i].SrcId));
            mxSetField(mach, i, "ChannelID", mxCreateDoubleScalar(sh[i].ChanId));
        } else
        {
            mxSetField(mach, i, "SourceID", mxCreateDoubleScalar(0));
            mxSetField(mach, i, "ChannelID", mxCreateDoubleScalar(0));
        }
    }

    return 0;
}

int scanPLXFile(mxArray *plx, FILE* fp, bool fullread)
{
    struct PL_FileHeader fh;
    struct PL_ChanHeader *spchans;
    struct PL_EventHeader *evchans;
    struct PL_SlowChannelHeader *slchans;
    
    char magic[] = "PLEX";
    int i, retval, *ChanADFreq, maxchans[3] = {0, 0, -1};
    unsigned int datastart;
    mxArray *datacounts[5];
    
    if(fread(&fh, sizeof(fh), 1, fp) != 1)
    {
        if(feof(fp)) return 1; /* Premature end of file */
        else if(ferror(fp)) return 2; /* File read error */
        else return 3;
    }
    
    if(fh.MagicNumber != *(int *)magic) return 4; /* Invalid PLX file */
    
    /* Read in spike channel headers */
    spchans = (struct PL_ChanHeader *)mxMalloc(fh.NumDSPChannels*sizeof(spchans[0]));
    if(fh.NumDSPChannels > 0 && spchans == NULL) return 5;
    if(fread(spchans, sizeof(spchans[0]), fh.NumDSPChannels, fp) != fh.NumDSPChannels)
    {
        if(feof(fp)) return 1; /* Premature end of file */
        else if(ferror(fp)) return 2; /* File read error */
        else return 3;
    }
    for(i = 0; i < fh.NumDSPChannels; i++)
        maxchans[0] = MAX(maxchans[0],spchans[i].Channel);
    
    /* Read in event channel headers */
    evchans = (struct PL_EventHeader *)mxMalloc(fh.NumEventChannels*sizeof(evchans[0]));
    if(fh.NumEventChannels > 0 && evchans == NULL) return 5;
    if(fread(evchans, sizeof(evchans[0]), fh.NumEventChannels, fp) != fh.NumEventChannels)
    {
        if(feof(fp)) return 1; /* Premature end of file */
        else if(ferror(fp)) return 2; /* File read error */
        else return 3;
    }
    for(i = 0; i < fh.NumEventChannels; i++)
        maxchans[1] = MAX(maxchans[1],evchans[i].Channel);
        
    /* Read in continuous channel headers */
    slchans = (struct PL_SlowChannelHeader *)mxMalloc(fh.NumSlowChannels*sizeof(slchans[0]));
    if(fh.NumSlowChannels > 0 && slchans == NULL) return 5;
    if(fread(slchans, sizeof(slchans[0]), fh.NumSlowChannels, fp) != fh.NumSlowChannels)
    {
        if(feof(fp)) return 1; /* Premature end of file */
        else if(ferror(fp)) return 2; /* File read error */
        else return 3;
    }
    for(i = 0; i < fh.NumSlowChannels; i++)
        maxchans[2] = MAX(maxchans[2],slchans[i].Channel);
    
    /* Determine the frequency of each AD channel */
    ChanADFreq = (int *)mxMalloc((maxchans[2]+1)*sizeof(int));
    if(maxchans[2] >= 0 && ChanADFreq == NULL) return 4;
    for(i = 0; i <= maxchans[2]; i++) ChanADFreq[i] = fh.ADFrequency;
    for(i = 0; i < fh.NumSlowChannels; i++)
        ChanADFreq[slchans[i].Channel] = slchans[i].ADFreq;
    
    /* Record the start location of the data */
    datastart = ftell(fp);
    
    /* Count the number of data blocks in the file */
    retval = tally(datacounts, fp, fh, maxchans, fullread, fh.ADFrequency, ChanADFreq);
    if(retval != 0) return 100+retval;
    
    /* Build a MATLAB structure from the data in the file header. */
    retval = buildFileHeadStruct(plx, fh);
    if(retval != 0) return 200+retval;
    
    /* Add data counts to the MATLAB structure. */
    if(    mxAddField(plx, "SpikeTimestampCounts"  ) < 0
        || mxAddField(plx, "SpikeWaveformCounts"   ) < 0
        || mxAddField(plx, "EventCounts"           ) < 0
        || mxAddField(plx, "ContSampleCounts"      ) < 0
        || mxAddField(plx, "ContSampleFragments"   ) < 0) return 6;
        
    mxSetField(plx, 0, "SpikeTimestampCounts" , datacounts[0]);    
    mxSetField(plx, 0, "SpikeWaveformCounts"  , datacounts[1]);
    mxSetField(plx, 0, "EventCounts"          , datacounts[2]);
    mxSetField(plx, 0, "ContSampleCounts"     , datacounts[3]);
    mxSetField(plx, 0, "ContSampleFragments"  , datacounts[4]);
    
    /* Build a MATLAB structure for the spike channel headers. */
    retval = buildChanHeadStruct( plx, spchans, fh.Version, fh.NumDSPChannels);
    if(retval != 0) return 200+retval;
    
    /* Build a MATLAB structure for the event channel headers. */
    retval = buildEventHeadStruct(plx, evchans, fh.Version, fh.NumEventChannels);
    if(retval != 0) return 200+retval;
    
    /* Build a MATLAB structure for the continuous channel headers. */
    retval = buildSlowHeadStruct( plx, slchans, fh.Version, fh.NumSlowChannels);
    if(retval != 0) return 200+retval;

    /* Free the memory used by the channel headers. */
    if(spchans != NULL) mxFree(spchans);
    if(evchans != NULL) mxFree(evchans);
    if(slchans != NULL) mxFree(slchans);
    if(ChanADFreq != NULL) mxFree(ChanADFreq);
    
    /* Note whether a full read was performed. */
    if(mxAddField(plx, "FullRead") < 0) return 7;
    mxSetField(plx, 0, "FullRead", mxCreateLogicalScalar(fullread));

    /* Store the start location of the data in the file. */
    if(mxAddField(plx, "DataStartLocation") < 0) return 8;
    mxSetField(plx, 0, "DataStartLocation", mxCreateDoubleScalar(datastart));

    return 0;
}

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
    bool fullread = false;
    /* 0 = 'spikes', 1 = 'waves', 2 = 'events',
     * 3 = 'continuous, 4 = 'units' */
    bool readtypes[5];
    char *fname, *arg;
    double start = 0, stop = 0, *range, *ptr;
    int first = 1, last = 0, num = 1, *channels[5], numchanin[5];
    UINT64_T starttick = 0, stoptick = -1;
    bool switches[4], haveheader = false, havenum = false;
    /* 0 = 'havestart', 1 = 'havestop',
     * 2 = 'havefirst', 3 = 'havelast' */
    const char helpstr[] = "For detailed help run: readPLXFileC('help')";
    int i, n, ADFrequency, retval = 0;
    int lastarg = -1, revnum;
    long offset = 0;
    
    FILE* fp;
    
    /* Check that inputs and outputs are OK */
    if(nrhs < 1)
        mexErrMsgIdAndTxt("readPLXFile:usage",
            "At least one input argument is required.\n%s", helpstr);
    else if(!mxIsChar(prhs[0]))
        mexErrMsgIdAndTxt("readPLXFile:usage",
            "First argument must be a filename (string), 'help', or 'version'.\n%s", helpstr);
    
    if(nlhs > 1)
        mexErrMsgIdAndTxt("readPLXFile:usage",
            "Too many output arguments.\n%s", helpstr);
    
    /* Copy the first input argument to the variable fname. */
    fname = mxArrayToString(prhs[0]);
    
    /* Check if the 'help' or 'version' information was requested. */
    if(strcmp(fname,"help") == 0)
    {
        revnum = disphelp();
        if(nlhs > 0) plhs[0] = mxCreateDoubleScalar(revnum);
        return;
    } else if(strcmp(fname,"version") == 0)
    {
        revnum = dispversion(nlhs == 0);
        if(nlhs > 0) plhs[0] = mxCreateDoubleScalar(revnum);
        return;
    }
    
    /* Initialize output structure. */
    plhs[0] = mxCreateStructMatrix(1,1,0,NULL);

    for(n = 0; n < 4; n++) switches[n] = false;
    for(n = 0; n < 5; n++)
    {
        readtypes[n] = false;
        channels[n] = NULL;
        numchanin[n] = 0;
    }
    readtypes[4] = true; /* by default, read all units */

    for(n = 1; n < nrhs; n++)
    {
        /* There can be three types of input: string, array, or structure */
        /* 0 = 'spikes', 1 = 'waves', 2 = 'events',
         * 3 = 'continuous, 4 = 'units' */
        if(n>1 && mxIsChar(prhs[n-1]) && !mxIsDouble(prhs[n]) && lastarg >= 4)
        {
            if(mxIsNumeric(prhs[n]) && !mxIsDouble(prhs[n]))
                mexErrMsgIdAndTxt("readPLXFile:usage",
                        "Numeric arguments must be of class 'double'.\n");
            mexErrMsgIdAndTxt("readPLXFile:usage",
                    "The argument '%s' must be followed by a numeric argument.\n%s", arg, helpstr);
        } else if(mxIsChar(prhs[n]))
        {
            lastarg = -1;
            arg = mxArrayToString(prhs[n]);
            if(strcmp(arg,"help") == 0)
                disphelp();
            else if(strcmp(arg,"version") == 0)
                dispversion(true);
            else if(strcmp(arg,"headers") == 0)
            {
                readtypes[0] = false; readtypes[1] = false;
                readtypes[2] = false; readtypes[3] = false;
            } else if(strcmp(arg,"all") == 0)
            {
                readtypes[0] = true; readtypes[1] = true;
                readtypes[2] = true; readtypes[3] = true;
            } else if(strcmp(arg,"fullread") == 0)
            {
                fullread = true;
            } else if(strcmp(arg,"nofullread") == 0)
            {
                fullread = false;
            } else if(strcmp(arg,"spikes") == 0)
            {
                readtypes[0] = true;
                lastarg = 0;
            } else if(strcmp(arg,"nospikes") == 0)
            {
                readtypes[0] = false;
                readtypes[1] = false;
            } else if(strcmp(arg,"waves") == 0)
            {
                readtypes[0] = true;
                readtypes[1] = true;
                lastarg = 1;
            } else if(strcmp(arg,"nowaves") == 0) readtypes[1] = false;
            else if(strcmp(arg,"events") == 0)
            {
                readtypes[2] = true;
                lastarg = 2;
            } else if(strcmp(arg,"noevents") == 0) readtypes[2] = false;
            else if(strcmp(arg,"continuous") == 0)
            {
                readtypes[3] = true;
                lastarg = 3;
            } else if(strcmp(arg,"nocontinuous") == 0) readtypes[3] = false;
            else if(strcmp(arg,"units") == 0)
            {
                lastarg = 4;
                readtypes[4] = true;
            } else if(strcmp(arg,"notunits") == 0)
            {
                lastarg = 4;
                readtypes[4] = false;
            } else if(strcmp(arg,"range") == 0) lastarg = 5;
            else if(strcmp(arg,"start") == 0) lastarg = 6;
            else if(strcmp(arg,"stop") == 0) lastarg = 7;
            else if(strcmp(arg,"first") == 0) lastarg = 8;
            else if(strcmp(arg,"num") == 0) lastarg = 9;
            else if(strcmp(arg,"last") == 0) lastarg = 10;
            else
                mexErrMsgIdAndTxt("readPLXFile:usage",
                        "Unrecognized string argument: %s\n%s", arg, helpstr);
        } else if(mxIsDouble(prhs[n]))
        {
            /* 0 = 'spikes', 1 = 'waves', 2 = 'events',
             * 3 = 'continuous, 4 = 'units' */
             if(lastarg >= 0 && lastarg <= 4)
            {
                if(channels[lastarg] != NULL); mxFree(channels[lastarg]);
                numchanin[lastarg] = (int)mxGetNumberOfElements(prhs[n]);
                ptr = mxGetPr(prhs[n]);
                channels[lastarg] = (int *)mxMalloc(numchanin[lastarg]*sizeof(int));
                for(i = 0; i < numchanin[lastarg]; i++)
                    channels[lastarg][i] = (int)ptr[i];
                lastarg = -1;
            } else if(lastarg == 5) /* 5 = range */
            {
                if(mxGetNumberOfElements(prhs[n])!=2)
                    mexErrMsgIdAndTxt("readPLXFile:usage",
                            "'range' requires a two element array.\n");
                range = mxGetPr(prhs[n]);
                start = range[0];
                stop = range[1];
                switches[0] = true;
                switches[1] = true;
            } else if(lastarg == 6) /* 6 = start */
            {
                if(mxGetNumberOfElements(prhs[n])!=1)
                    mexErrMsgIdAndTxt("readPLXFile:usage",
                            "'start' requires a scalar double.\n");
                start = mxGetScalar(prhs[n]);
                if(start < 0) start = 0;
                switches[0] = true;
            } else if(lastarg == 7) /* 7 = stop */
            {
                if(mxGetNumberOfElements(prhs[n])!=1)
                    mexErrMsgIdAndTxt("readPLXFile:usage",
                            "'stop' requires a scalar double.\n");
                stop = mxGetScalar(prhs[n]);
                switches[1] = true;
            } else if(lastarg == 8) /* 8 = first */
            {
                if(mxGetNumberOfElements(prhs[n])!=1)
                    mexErrMsgIdAndTxt("readPLXFile:usage",
                            "'first' requires a scalar.\n");
                first = (int)mxGetScalar(prhs[n]);
                switches[2] = true;
                if(havenum)
                {
                    last = first+num-1;
                    switches[3] = true;
                    havenum = false;
                }
            } else if(lastarg == 9) /* 9 = num */
            {
                if(mxGetNumberOfElements(prhs[n])!=1)
                    mexErrMsgIdAndTxt("readPLXFile:usage",
                            "'num' requires a scalar.\n");
                num = (int)mxGetScalar(prhs[n]);
                if(switches[2])
                {
                    last = first+num-1;
                    switches[3] = true;
                } else if(switches[3])
                {
                    first = last-num+1;
                    switches[2] = true;
                } else havenum = true;
            } else if(lastarg == 10) /* 10 = last */
            {
                if(mxGetNumberOfElements(prhs[n])!=1)
                    mexErrMsgIdAndTxt("readPLXFile:usage",
                            "'last' requires a scalar.\n");
                last = (int)mxGetScalar(prhs[n]);
                switches[3] = true;
                if(havenum)
                {
                    first = last-num+1;
                    switches[2] = true;
                    havenum = false;
                }
            } else
                mexErrMsgIdAndTxt("readPLXFile:usage",
                        "Unexpected numerical argument.\n%s", helpstr);
            lastarg = -1;
        } else if(mxIsStruct(prhs[n])) /* headers provided as structure */
        {
            if(verifyPLXStruct(prhs[n]))
            {
                mxDestroyArray(plhs[0]);
                plhs[0] = mxDuplicateArray(prhs[n]);
                haveheader = true;
            }
        } else
            mexErrMsgIdAndTxt("readPLXFile:usage",
                    "Unexpected argument.\n%s", helpstr);
    }
    if(lastarg >= 4)
        mexErrMsgIdAndTxt("readPLXFile:usage",
                "The argument '%s' must be followed by a numeric argument.\n", arg);
    
    if(readtypes[0] || readtypes[1] || readtypes[2] || readtypes[3])
        fullread = true;

    /* If a header was supplied, but it wasn't a full read, but a full read
     * is necessary, then clear out the header supplied. */
    if(haveheader && fullread && 
            ~mxIsLogicalScalarTrue(mxGetField(plhs[0], 0, "FullRead")))
    {
        mxDestroyArray(plhs[0]);
        plhs[0] = mxCreateStructMatrix(1,1,0,NULL);
        haveheader = false;
    }
    
    /* Open file for reading. */
    fp = fopen(fname,"rb");
    
    if(fp == 0) mexErrMsgIdAndTxt("readPLXFile:fileerror",
        "Error opening file: %s\n", fname);
    
    /* If necessary, read the file headers. */
    if(!haveheader) retval = scanPLXFile(plhs[0], fp, fullread);
    
    /* If necessary, read the file data. */
    if(retval == 0 && (readtypes[0] || readtypes[1] || readtypes[2] || readtypes[3]))
    {
        ADFrequency = (int)mxGetScalar(mxGetField(plhs[0], 0, "ADFrequency"));
        starttick = (int)(start*ADFrequency);
        stoptick = (int)(stop*ADFrequency);

        retval = readPLXData(plhs[0], fp, readtypes, numchanin, channels, 
                starttick, stoptick, first, last, switches);
    }
    
    for(n = 0; n < 5; n++) if(channels[n] != NULL) mxFree(channels[n]);

    offset = ftell(fp);
    fclose(fp);
    
    switch(retval)
    {
        case 0: break;
        case 1: mexErrMsgIdAndTxt("readPLXFile:fileerror:prematureEOF",
            "Error reading file: premature end of file (%d)",retval);
            break;
        case 2: mexErrMsgIdAndTxt("readPLXFile:fileerror",
            "Error reading file: error code %d", ferror(fp));
            break;
        case 3: mexErrMsgIdAndTxt("readPLXFile:fileerror:errorReading",
            "Error reading file (%d)",retval);
            break;
        case 4: mexErrMsgIdAndTxt("readPLXFile:invalidPLXfile",
            "Invalid PLX file (%d)",retval);
            break;
        case 5: mexErrMsgIdAndTxt("readPLXFile:mxMalloc",
            "\"mxMalloc\" failed to allocate the necessary memory (%d)",retval);
            break;
        case 6: mexErrMsgIdAndTxt("readPLXFile:fileHeaders:channelHeader",
            "Failed to create fields for channel headers (%d)",retval);
            break;
        case 7: mexErrMsgIdAndTxt("readPLXFile:fileHeaders:fullread",
            "Failed to create field to store full read status (%d)",retval);
            break;
        case 8: mexErrMsgIdAndTxt("readPLXFile:fileHeaders:datastart",
            "Failed to create field to store data start location (%d)",retval);
            break;
        case 9: mexErrMsgIdAndTxt("readPLXFile:fileerror:errorSeeking",
            "Error seeking to data start location (%d)",retval);
            break;
        case 10: mexErrMsgIdAndTxt("readPLXFile:readData:createDataField",
            "Failed to create field to store data (%d)",retval);
            break;
        case 101: mexErrMsgIdAndTxt("readPLXFile:tally:invalidType",
            "Invalid data block header type (%d, offset: 0x%X)",retval, offset);
            break;
        case 102: mexErrMsgIdAndTxt("readPLXFile:tally:invalidChannel",
            "Invalid channel number (%d, offset: 0x%X)",retval, offset);
            break;
        case 103: mexErrMsgIdAndTxt("readPLXFile:tally:invalidNumWaves",
            "Invalid number of waveforms (%d, offset: 0x%X).",retval, offset);
            break;
        case 104: mexErrMsgIdAndTxt("readPLXFile:tally:invalidUnit",
            "Invalid unit number (%d, offset: 0x%X)",retval, offset);
            break;
        case 105: mexErrMsgIdAndTxt("readPLXFile:tally:incompleteDataBlock",
            "Incomplete data block (%d, offset: 0x%X)",retval, offset);
            break;
        case 106: mexErrMsgIdAndTxt("readPLXFile:tally:mxMalloc",
            "\"mxMalloc\" failed to allocate the necessary memory (%d)",retval);
            break;
        case 201: mexErrMsgIdAndTxt("readPLXFile:fileHeader:createHeaderField",
            "Failed to create field in file header (%d)",retval);
            break;
        case 202: mexErrMsgIdAndTxt("readPLXFile:badPLXdate",
            "Error converting PLX date using \"datenum\" (%d)",retval);
            break;
        case 203: mexErrMsgIdAndTxt("readPLXFile:spikeHeaders:createSpikeHeader",
            "Failed to create field to store spike channel headers (%d)",retval);
            break;
        case 204: mexErrMsgIdAndTxt("readPLXFile:spikeHeaders:createSpikeHeaderField",
            "Failed to create field in spike channel header (%d)",retval);
            break;
        case 205: mexErrMsgIdAndTxt("readPLXFile:eventHeaders:createEventHeader",
            "Failed to create field to store event channel headers (%d)",retval);
            break;
        case 206: mexErrMsgIdAndTxt("readPLXFile:eventHeaders:createEventHeaderField",
            "Failed to create field in event channel header (%d)",retval);
            break;
        case 207: mexErrMsgIdAndTxt("readPLXFile:continuousHeaders:createContHeader",
            "Failed to create field to store continuous channel headers (%d)",retval);
            break;
        case 208: mexErrMsgIdAndTxt("readPLXFile:continuousHeaders:createContHeaderField",
            "Failed to create field in continuous channel header (%d)",retval);
            break;
        case 510: mexErrMsgIdAndTxt("readPLXFile:readData:mxMalloc:spikeTimestamps",
            "\"mxMalloc\" failed to allocate memory necessary for spike timestamps (%d)",retval);
            break;
        case 511: mexErrMsgIdAndTxt("readPLXFile:readData:mxMalloc:spikeUnits",
            "\"mxMalloc\" failed to allocate memory necessary for spike units (%d)",retval);
            break;
        case 512: mexErrMsgIdAndTxt("readPLXFile:readData:mxMalloc:spikeWaves",
            "\"mxMalloc\" failed to allocate memory necessary for spike waveforms (%d)",retval);
            break;
        case 520: mexErrMsgIdAndTxt("readPLXFile:readData:mxMalloc:eventTimestamps",
            "\"mxMalloc\" failed to allocate memory necessary for event timestamps (%d)",retval);
            break;
        case 521: mexErrMsgIdAndTxt("readPLXFile:readData:mxMalloc:eventValues",
            "\"mxMalloc\" failed to allocate memory necessary for event values (%d)",retval);
            break;
        case 530: mexErrMsgIdAndTxt("readPLXFile:readData:mxMalloc:continuousTimestamps",
            "\"mxMalloc\" failed to allocate memory necessary for continuous timestamps (%d)",retval);
            break;
        case 531: mexErrMsgIdAndTxt("readPLXFile:readData:mxMalloc:continuousFragments",
            "\"mxMalloc\" failed to allocate memory necessary for continuous fragments (%d)",retval);
            break;
        case 532: mexErrMsgIdAndTxt("readPLXFile:readData:mxMalloc:continuousValues",
            "\"mxMalloc\" failed to allocate memory necessary for continuous values (%d)",retval);
            break;
        default: mexErrMsgIdAndTxt("readPLXFile:unrecognizedError",
            "Unrecognized error code: %d", retval);
    }
}
