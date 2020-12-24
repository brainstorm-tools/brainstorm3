function data = TDTbin2mat(BLOCK_PATH, varargin)
%TDTBIN2MAT  TDT tank data extraction.
%   data = TDTbin2mat(BLOCK_PATH), where BLOCK_PATH is a string, retrieves
%   all data from specified block directory in struct format.  This reads
%   the binary tank data and requires no Windows-based software.
%
%   data.epocs      contains all epoc store data (onsets, offsets, values)
%   data.snips      contains all snippet store data (timestamps, channels,
%                   and raw data)
%   data.streams    contains all continuous data (sampling rate and raw
%                   data)
%   data.scalars    contains all scalar data (samples and timestamps)
%   data.info       contains additional information about the block
%
%   'parameter', value pairs
%        'T1'         scalar, retrieve data starting at T1 (default = 0 for
%                         beginning of recording)
%        'T2'         scalar, retrieve data ending at T2 (default = 0 for end
%                         of recording)
%        'SORTNAME'   string, specify sort ID to use when extracting snippets
%        'TYPE'       array of scalars or cell array of strings, specifies
%                         what type of data stores to retrieve from the tank
%                     1: all (default)
%                     2: epocs
%                     3: snips
%                     4: streams
%                     5: scalars
%                     TYPE can also be cell array of any combination of
%                         'epocs', 'streams', 'scalars', 'snips', 'all'
%                     examples:
%                         data = TDTbin2mat('MyTank','Block-1','TYPE',[1 2]);
%                             > returns only epocs and snips
%                         data = TDTbin2mat('MyTank','Block-1','TYPE',{'epocs','snips'});
%                             > returns only epocs and snips
%      'RANGES'     array of valid time range column vectors
%      'NODATA'     boolean, only return timestamps, channels, and sort 
%                       codes for snippets, no waveform data (default = false)
%      'STORE'      string, specify a single store to extract
%      'CHANNEL'    integer, choose a single channel, to extract from
%                       stream or snippet events. Default is 0, to extract
%                       all channels.
%      'BITWISE'    string, specify an epoc store or scalar store that 
%                       contains individual bits packed into a 32-bit 
%                       integer. Onsets/offsets from individual bits will
%                       be extracted.
%      'HEADERS'    var, set to 1 to return only the headers for this
%                       block, so that you can make repeated calls to read
%                       data without having to parse the TSQ file every
%                       time. Or, pass in the headers using this parameter.
%                   example:
%                       heads = TDTbin2mat(BLOCK_PATH, 'HEADERS', 1);
%                       data = TDTbin2mat(BLOCK_PATH, 'HEADERS', heads, 'TYPE', {'snips'});
%                       data = TDTbin2mat(BLOCK_PATH, 'HEADERS', heads, 'TYPE', {'streams'});
%      'COMBINE'    cell, specify one or more data stores that were saved 
%                       by the Strobed Data Storage gizmo in Synapse (or an
%                       Async_Stream_Store macro in OpenEx). By default,
%                       the data is stored in small chunks while the strobe
%                       is high. This setting allows you to combine these
%                       small chunks back into the full waveforms that were
%                       recorded while the strobe was enabled.
%                   example:
%                       data = TDTbin2mat(BLOCK_PATH, 'COMBINE', {'StS1'});
%

% defaults
BITWISE  = '';
CHANNEL  = 0;
COMBINE  = {};
HEADERS  = 0;
NODATA   = false;
RANGES   = [];
STORE    = '';
T1       = 0;
T2       = 0;
TYPE     = 1:5;
VERBOSE  = 0;
SORTNAME = 'TankSort';

VALID_PARS = {'BITWISE','CHANNEL','HEADERS','NODATA','RANGES','STORE', ...
    'T1','T2','TYPE','VERBOSE','SORTNAME','COMBINE'};

% parse varargin
for ii = 1:2:length(varargin)
    if ~ismember(upper(varargin{ii}), VALID_PARS)
        error('%s is not a valid parameter. See help TDTbin2mat.', upper(varargin{ii}));
    end
    eval([upper(varargin{ii}) '=varargin{ii+1};']);
end

ALLOWED_TYPES = {'ALL','EPOCS','SNIPS','STREAMS','SCALARS'};

if iscell(TYPE)
    types = zeros(1, numel(TYPE));
    for ii = 1:numel(TYPE)
        ind = find(strcmpi(ALLOWED_TYPES, TYPE{ii}));
        if isempty(ind)
            error('Unrecognized type: %s\nAllowed types are: %s', TYPE{ii}, sprintf('%s ', ALLOWED_TYPES{:}))
        end
        if ind == 1
            types = 1:5;
            break;
        end
        types(ii) = ind;
    end
    TYPE = unique(types);
else
    if ~isnumeric(TYPE), error('TYPE must be a scalar, number vector, or cell array of strings'), end
    if TYPE == 1, TYPE = 1:5; end
end

useOutsideHeaders = 0;
doHeadersOnly = 0;
if isa(HEADERS, 'struct')
    useOutsideHeaders = 1;
    headerStruct = HEADERS;
    clear HEADERS;
else
    headerStruct = struct();
    if HEADERS == 1
        doHeadersOnly = 1;
    end
end

% Tank event types (tsqEventHeader.type)
global EVTYPE_UNKNOWN EVTYPE_STRON EVTYPE_STROFF EVTYPE_SCALAR EVTYPE_STREAM  EVTYPE_SNIP;
global EVTYPE_MARK EVTYPE_HASDATA EVTYPE_UCF EVTYPE_PHANTOM EVTYPE_MASK EVTYPE_INVALID_MASK;
EVTYPE_UNKNOWN  = hex2dec('00000000');
EVTYPE_STRON    = hex2dec('00000101');
EVTYPE_STROFF	= hex2dec('00000102');
EVTYPE_SCALAR	= hex2dec('00000201');
EVTYPE_STREAM	= hex2dec('00008101');
EVTYPE_SNIP		= hex2dec('00008201');
EVTYPE_MARK		= hex2dec('00008801');
EVTYPE_HASDATA	= hex2dec('00008000');
EVTYPE_UCF		= hex2dec('00000010');
EVTYPE_PHANTOM	= hex2dec('00000020');
EVTYPE_MASK		= hex2dec('0000FF0F');
EVTYPE_INVALID_MASK	= hex2dec('FFFF0000');

EVMARK_STARTBLOCK	= hex2dec('0001');
EVMARK_STOPBLOCK	= hex2dec('0002');

global DFORM_FLOAT DFORM_LONG DFORM_SHORT DFORM_BYTE
global DFORM_DOUBLE DFORM_QWORD DFORM_TYPE_COUNT
DFORM_FLOAT		 = 0;
DFORM_LONG		 = 1;
DFORM_SHORT		 = 2;
DFORM_BYTE		 = 3;
DFORM_DOUBLE	 = 4;
DFORM_QWORD		 = 5;
DFORM_TYPE_COUNT = 6;

ALLOWED_FORMATS = {'single','int32','int16','int8','double','int64'};

% % TTank event header structure
% tsqEventHeader = struct(...
%     'size', 0, ...
%     'type', 0, ...  % (long) event type: snip, pdec, epoc etc
%     'code', 0, ...  % (long) event name: must be 4 chars, cast as a long
%     'channel', 0, ... % (unsigned short) data acquisition channel
%     'sortcode', 0, ... % (unsigned short) sort code for snip data. See also OpenSorter .SortResult file.
%     'timestamp', 0, ... % (double) time offset when even occurred
%     'ev_offset', 0, ... % (int64) data offset in the TEV file OR (double) strobe data value
%     'format', 0, ... % (long) data format of event: byte, short, float (typical), or double
%     'frequency', 0 ... % (float) sampling frequency
% );

if strcmp(BLOCK_PATH(end), '\') ~= 1 && strcmp(BLOCK_PATH(end), '/') ~= 1
    BLOCK_PATH = [BLOCK_PATH filesep];
end

if ~useOutsideHeaders
    tsqList = dir([BLOCK_PATH '*.tsq']);
    if length(tsqList) < 1
        if ~exist(BLOCK_PATH, 'dir')
            error('block path %s not found', BLOCK_PATH)
        end
        warning('no TSQ file found, attempting to read SEV files')
        data = SEV2mat(BLOCK_PATH, varargin{:});
        return
    elseif length(tsqList) > 1
        error('multiple TSQ files found')
    end
    
    cTSQ = [BLOCK_PATH tsqList(1).name];
    tsq = fopen(cTSQ, 'rb');
    if tsq < 0
        error('TSQ file could not be opened')
    end
    headerStruct.tevPath = [BLOCK_PATH strrep(tsqList(1).name, '.tsq', '.tev')];
end

if ~doHeadersOnly
    tev = fopen(headerStruct.tevPath, 'rb');
    if tev < 0
        error('TEV file could not be opened')
    end
end

% look for epoch tagged notes
tntPath = strrep(headerStruct.tevPath, '.tev', '.tnt');
noteStr = {};
try
    tnt = fopen(tntPath, 'rt');
    % get file version in first line
    fgetl(tnt);
    ind = 1;
    while ~feof(tnt)
        noteStr{ind} = fgetl(tnt);
        ind = ind + 1;
    end
    fclose(tnt);
catch
    warning('TNT file could not be processed')
end

customSortEvent = '';
customSortChannelMap = zeros(1,1024);
customSortCodes = [];

% look for SortIDs
if ismember(3, TYPE) && ~strcmp(SORTNAME, 'TankSort')
    sortIDs = struct();
    sortIDs.fileNames = {};
    sortIDs.event = {};
    sortIDs.sortID = {};
    
    SORT_PATH = [BLOCK_PATH 'sort'];
    sortFolders = dir(SORT_PATH);
    
    ind = 1;
    for ii = 3:numel(sortFolders)
        if sortFolders(ii).isdir
            % parse sort result file name
            sortFile = dir([SORT_PATH filesep sortFolders(ii).name filesep '*.SortResult']);
            periodInd = strfind(sortFile(1).name, '.');
            sortIDs.event{ind} = '';
            if ~isempty(periodInd)
                sortIDs.event{ind} = sortFile(1).name(1:periodInd(end)-1);
            end
            sortIDs.fileNames{ind} = [[SORT_PATH filesep sortFolders(ii).name] filesep sortFile(1).name];
            sortIDs.sortID{ind} = sortFolders(ii).name;
            ind = ind + 1;
        end
    end
    
    % OpenSorter sort codes file structure
    % ------------------------------------
    % Sort codes saved by OpenSorter are stored in block subfolders such as
    % Block-3\sort\USERDEFINED\EventName.SortResult.
    %
    % .SortResult files contain sort codes for 1 to all channels within
    % the selected block.  Each file starts with a 1024 byte boolean channel
    % map indicating which channel's sort codes have been saved in the file.
    % Following this map, is a sort code field that maps 1:1 with the event
    % ID for a given block.  The event ID is essentially the Nth occurance of
    % an event on the entire TSQ file.
    
    % look for the exact one
    [lia, loc] = ismember(SORTNAME, sortIDs.sortID);
    if ~lia
        warning('SortID: %s not found\n', SORTNAME);
    else
        fprintf('Using SortID: %s for event: %s\n', SORTNAME, sortIDs.event{loc});
        customSortEvent = sortIDs.event{loc};
        fid = fopen(sortIDs.fileNames{loc}, 'rb');
        customSortChannelMap = fread(fid, 1024);
        customSortCodes = uint16(fread(fid, Inf, '*char'));
        fclose(fid);
    end
end

%{
 tbk file has block events information and on second time offsets
 to efficiently locate events if the data is queried by time.

 tsq file is a list of event headers, each 40 bytes long, ordered strictly
 by time.

 tev file contains event binary data

 tev and tsq files work together to get an event's data and attributes

 tdx file contains just information about epoc stores,
 is optionally generated after recording for fast retrieval
 of epoc information
%}

% read TBK notes to get event info
tbkPath = strrep(headerStruct.tevPath, '.tev', '.Tbk');
blockNotes = parseTBK(tbkPath);

if ~useOutsideHeaders
    % read start time
    file_size = fread(tsq, 1, '*int64');
    fseek(tsq, 48, 'bof');
    code1 = fread(tsq, 1, '*int32');
    assert(code1 == EVMARK_STARTBLOCK, 'Block start marker not found');
    fseek(tsq, 56, 'bof');
    headerStruct.startTime = fread(tsq, 1, '*double');
    
    % read stop time
    fseek(tsq, -32, 'eof');
    code2 = fread(tsq, 1, '*int32');
    if code2 ~= EVMARK_STOPBLOCK
        warning('Block end marker not found');
        headerStruct.stopTime = nan;
    else
        fseek(tsq, -24, 'eof');
        headerStruct.stopTime = fread(tsq, 1, '*double');
    end
end

data = struct('epocs', [], 'snips', [], 'streams', [], 'scalars', []);

% set info fields
[data.info.tankpath, data.info.blockname] = fileparts(BLOCK_PATH(1:end-1));
data.info.date = datestr(datenum([1970, 1, 1, 0, 0, headerStruct.startTime]),'yyyy-mmm-dd');
if ~isnan(headerStruct.startTime)
    data.info.utcStartTime = datestr(datenum([1970, 1, 1, 0, 0, headerStruct.startTime]),'HH:MM:SS');
else
    data.info.utcStartTime = nan;
end
if ~isnan(headerStruct.stopTime)
    data.info.utcStopTime = datestr(datenum([1970, 1, 1, 0, 0, headerStruct.stopTime]),'HH:MM:SS');
else
    data.info.utcStopTime = nan;
end

s1 = datenum([1970, 1, 1, 0, 0, headerStruct.startTime]);
s2 = datenum([1970, 1, 1, 0, 0, headerStruct.stopTime]);
if headerStruct.stopTime > 0
    data.info.duration = datestr(s2-s1,'HH:MM:SS');
end
data.info.streamChannel = CHANNEL;
data.info.snipChannel = CHANNEL;

% look for Synapse recording notes
notesTxtPath = [BLOCK_PATH 'Notes.txt'];
noteTxtLines = {};
try
    txt = fopen(notesTxtPath, 'rt');
    ind = 1;
    while ~feof(txt)
        noteTxtLines{ind} = fgetl(txt);
        ind = ind + 1;
    end
    fclose(txt);
    fprintf('Found Synapse note file: %s\n', notesTxtPath);
catch
    %warning('Synapse Notes file could not be processed')
end

NoteText = {};
if ~isempty(noteTxtLines)
    targets = {'Experiment','Subject','User','Start','Stop'};
    NoteText = cell(numel(noteTxtLines),1);
    noteInd = 1;
    for n = 1:numel(noteTxtLines)
        noteLine = noteTxtLines{n};
        if isempty(noteLine)
            continue
        end
        bTargetFound = false;
        for t = 1:length(targets)
            testStr = [targets{t} ':'];
            eee = length(testStr);
            if length(noteLine) >= eee + 2
                if strcmp(noteLine(1:eee), testStr)
                    data.info.(targets{t}) = noteLine(eee+2:end);
                    bTargetFound = true;
                    break
                end
            end
        end
        if bTargetFound
            continue
        end

        % look for actual notes
        testStr = 'Note-';
        eee = length(testStr);
        if length(noteLine) >= eee + 2
            if strcmp(noteLine(1:eee), testStr)
                noteInd = str2double(noteLine(strfind(noteLine,'-')+1:strfind(noteLine,':')-1));
                noteIdentifier = noteLine(strfind(noteLine, '[')+1:strfind(noteLine,']')-1);
                if strcmp(noteIdentifier, 'none')
                    quotes = strfind(noteLine, '"');
                    NoteText{noteInd} = noteLine(quotes(1)+1:quotes(2)-1);
                else
                    NoteText{noteInd} = noteIdentifier;
                end            
            end
        end
    end
    NoteText = NoteText(1:noteInd);
end

epocs = struct;
epocs.name = {};
epocs.buddies = {};
epocs.ts = {};
epocs.code = {};
epocs.type = {};
epocs.typeStr = {};
epocs.data = {};
epocs.dform = {};

notes = struct;
notes.name = {};
notes.index = {};
notes.ts = {};

if ~useOutsideHeaders
    %tsqFileSize = fread(tsq, 1, '*int64');
    fseek(tsq, 40, 'bof');
    
    loopCt = 0;
    if T2 > 0
        % make the reads shorter if we are stopping early
        readSize = 10000000;
    else
        readSize = 50000000;
    end
    
    % map store code to other info
    headerStruct.stores = struct();
    while ~feof(tsq)
        loopCt = loopCt + 1;
        
        % read all headers into one giant array
        heads = fread(tsq, readSize*4, '*uint8');
        heads = typecast(heads, 'uint32');
        
        % reshape so each column is one header
        if mod(numel(heads), 10) ~= 0
            warning('block did not end cleanly, removing last %d headers', mod(numel(heads), 10))
            heads = heads(1:end-mod(numel(heads), 10));
        end
        heads = reshape(heads, 10, []);
        
        % check the codes first and build store maps and note arrays
        codes = heads(3,:);
        
        % find unique stores and a pointed to one of their headers
        sortedCodes = sort(codes);
        uniqueCodes = sortedCodes([true,diff(sortedCodes)>0]);
        temp = zeros(size(uniqueCodes));
        for ii = 1:numel(uniqueCodes)
            temp(ii) = find(codes == uniqueCodes(ii), 1);
        end
        [sortedCodes, y] = sort(temp);
        
        % process them in the order they appear in the block though
        uniqueCodes = uniqueCodes(y);
        
        storeTypes = cell(1, numel(uniqueCodes));
        ucf = cell(1, numel(uniqueCodes));
        goodStoreCodes = [];
        for x = 1:numel(uniqueCodes)
            if uniqueCodes(x) == EVMARK_STARTBLOCK || uniqueCodes(x) == EVMARK_STOPBLOCK
                continue;
            end
            if uniqueCodes(x) == 0
                warning('skipping unknown header code 0.')
                continue
            end
            
            name = char(typecast(uniqueCodes(x), 'uint8'));
            
            % if looking for a particular store and this isn't it, skip it
            if ~strcmp(STORE, '') && ~strcmp(STORE, name), continue; end
            
            bSkipDisabled = 0;
            for i = 1:numel(blockNotes)
                temp = blockNotes(i);
                if strcmp(temp.StoreName, name)
                    if strcmp(temp.Enabled, '2')
                        %disp([temp.StoreName ' STORE DISABLED'])
                        bSkipDisabled = 1;
                        break;
                    end
                end
            end
            
            if bSkipDisabled
                continue
            end
            
            varName = fixVarName(name);
            storeTypes{x} = code2type(heads(2,sortedCodes(x)));
            ucf{x} = checkUCF(heads(2,sortedCodes(x)));
            
            % do store type filter here
            bUseStore = false;
            if ~any(TYPE == 1)
                for ii = 1:numel(TYPE)
                    if strcmpi(ALLOWED_TYPES{TYPE(ii)}, storeTypes{x})
                        bUseStore = true;
                    end
                end
            else
                bUseStore = true;
            end
            if ~bUseStore
                continue;
            else
                goodStoreCodes = union(goodStoreCodes, uniqueCodes(x));
            end
            
            if strcmp(storeTypes{x}, 'epocs')
                if ~ismember(name, epocs.name)
                    temp = typecast(heads(4, sortedCodes(x)), 'uint16');
                    buddy1 = char(typecast(temp(1), 'uint8'));
                    buddy2 = char(typecast(temp(2), 'uint8'));
                    epocs.name = [epocs.name {name}];
                    epocs.buddies = [epocs.buddies {[buddy1 buddy2]}];
                    epocs.code = [epocs.code {uniqueCodes(x)}];
                    epocs.ts = [epocs.ts {[]}];
                    epocs.type = [epocs.type {epoc2type(heads(2,sortedCodes(x)))}];
                    epocs.typeStr = [epocs.typeStr storeTypes(x)];
                    epocs.typeNum = 2;
                    epocs.data = [epocs.data {[]}];
                    epocs.dform = [epocs.dform {heads(9,sortedCodes(x))}];
                end
            end
            
            % add store information to store map
            if ~isfield(headerStruct.stores, varName)
                if ~strcmp(storeTypes{x}, 'epocs')
                    headerStruct.stores.(varName) = struct();
                    headerStruct.stores.(varName).name = name;
                    headerStruct.stores.(varName).code = uniqueCodes(x);
                    headerStruct.stores.(varName).size = heads(1,sortedCodes(x));
                    headerStruct.stores.(varName).type = heads(2,sortedCodes(x));
                    headerStruct.stores.(varName).typeStr = storeTypes{x};
                    headerStruct.stores.(varName).typeNum = find(strcmpi(ALLOWED_TYPES, storeTypes{x}));
                    if strcmp(storeTypes{x}, 'streams')
                        headerStruct.stores.(varName).ucf = ucf{x};
                    end
                    if ~strcmp(storeTypes{x}, 'scalars')
                        headerStruct.stores.(varName).fs = double(typecast(heads(10,sortedCodes(x)), 'single'));
                    end
                    headerStruct.stores.(varName).dform = heads(9,sortedCodes(x));
                end
            end
            
            validInd = find(codes == uniqueCodes(x));
            
            % look for notes in 'freqs' field for epoch or scalar events
            if numel(noteStr) > 0 && (strcmp(storeTypes{x}, 'scalars') || strcmp(storeTypes{x}, 'epocs'))
                
                % find all possible notes
                myNotes = typecast(heads(10,validInd), 'single');
                
                % find only where note field is non-zero and extract those
                noteInd = myNotes ~= 0;
                if any(noteInd)
                    if ~ismember(name, notes.name)
                        notes.name = [notes.name {name}];
                        notes.ts = [notes.ts {[]}];
                        notes.index = [notes.index {[]}];
                    end
                    tsInd = validInd(noteInd);
                    noteTS = typecast(reshape(heads(5:6, tsInd), 1, []), 'double') - headerStruct.startTime;
                    noteIndex = typecast(myNotes(noteInd),'uint32');
                    
                    [lia, loc] = ismember(name, notes.name);
                    notes.ts{loc} = [notes.ts{loc} noteTS];
                    notes.index{loc} = [notes.index{loc} noteIndex];
                end
            end
            
            temp = typecast(heads(4, validInd), 'uint16');
            if ~strcmp(storeTypes{x},'epocs')
                headerStruct.stores.(varName).ts{loopCt} = typecast(reshape(heads(5:6, validInd), 1, []), 'double') - headerStruct.startTime;
                if ~NODATA || strcmp(storeTypes{x},'streams')
                    headerStruct.stores.(varName).data{loopCt} = typecast(reshape(heads(7:8, validInd), 1, []), 'double');
                end
                headerStruct.stores.(varName).chan{loopCt} = temp(1:2:end);
                if strcmpi(headerStruct.stores.(varName).typeStr, 'snips')
                    if ~isempty(customSortCodes) && strcmp(headerStruct.stores.(varName).name, customSortEvent)
                        % apply custom sort codes
                        sortChannels = find(customSortChannelMap) - 1;
                        headerStruct.stores.(varName).sortcode{loopCt} = customSortCodes(validInd)';
                        headerStruct.stores.(varName).sortname = SORTNAME;
                        headerStruct.stores.(varName).sortchannels = sortChannels;
                    else
                        headerStruct.stores.(varName).sortcode{loopCt} = temp(2:2:end);
                        headerStruct.stores.(varName).sortname = 'TankSort';
                    end
                end
            else
                [lia, loc] = ismember(name, epocs.name);
                epocs.ts{loc} = [epocs.ts{loc} typecast(reshape(heads(5:6, validInd), 1, []), 'double') - headerStruct.startTime];
                epocs.data{loc} = [epocs.data{loc} typecast(reshape(heads(7:8, validInd), 1, []), 'double')];
            end
            
            clear temp;
        end
        clear codes;
        
        lastTS = typecast(reshape(heads(5:6, end), 1, []), 'double') - headerStruct.startTime;
        
        % break early if time filter
        if T2 > 0 && lastTS > T2
            break
        end
    end
    fprintf('read up to t=%.2fs\n', lastTS);
    
    % put epocs into headerStruct
    for ii = 1:numel(epocs.name)
        % find all non-buddies first
        if strcmp(epocs.type{ii}, 'onset')
            varName = fixVarName(epocs.name{ii});
            headerStruct.stores.(varName).name = epocs.name{ii};
            ts = epocs.ts{ii};
            headerStruct.stores.(varName).onset = ts;
            headerStruct.stores.(varName).offset = [ts(2:end) Inf];
            headerStruct.stores.(varName).type = epocs.type{ii};
            headerStruct.stores.(varName).typeStr = epocs.typeStr{ii};
            headerStruct.stores.(varName).typeNum = 2;
            headerStruct.stores.(varName).data = epocs.data{ii};
            headerStruct.stores.(varName).dform = epocs.dform{ii};
            headerStruct.stores.(varName).size = 10;
        end
    end
    
    % add all buddy epocs
    for ii = 1:numel(epocs.name)
        if strcmp(epocs.type{ii}, 'offset')
            varName = fixVarName(epocs.buddies{ii});
            headerStruct.stores.(varName).offset = epocs.ts{ii};
            
            % handle odd case where there is a single offset event and no 
            % onset events
            if ~isfield(headerStruct.stores.(varName), 'onset')
                headerStruct.stores.(varName).name = epocs.buddies{ii};
                headerStruct.stores.(varName).onset = 0;
                headerStruct.stores.(varName).typeStr = 'epocs';
                headerStruct.stores.(varName).typeNum = 2;
                headerStruct.stores.(varName).type = 'onset';
                headerStruct.stores.(varName).data = 0;
                headerStruct.stores.(varName).dform = 4;
                headerStruct.stores.(varName).size = 10;
            end
            
            % fix time ranges
            if headerStruct.stores.(varName).offset(1) < headerStruct.stores.(varName).onset(1)
                headerStruct.stores.(varName).onset = [0 headerStruct.stores.(varName).onset];
                headerStruct.stores.(varName).data = [headerStruct.stores.(varName).data(1) headerStruct.stores.(varName).data];
            end
            if headerStruct.stores.(varName).onset(end) > headerStruct.stores.(varName).offset(end)
                headerStruct.stores.(varName).offset = [headerStruct.stores.(varName).offset Inf];
            end
        end
    end
    clear epocs;
    
    fff = fields(headerStruct.stores);
    for xxx = 1:numel(fff)
        
        varName = fff{xxx};
        
        % convert cell arrays to regular arrays
        if isfield(headerStruct.stores.(varName), 'ts')
            headerStruct.stores.(varName).ts = cat(2,headerStruct.stores.(varName).ts{:});
        end
        if isfield(headerStruct.stores.(varName), 'chan')
            headerStruct.stores.(varName).chan = cat(2,headerStruct.stores.(varName).chan{:});
        end
        if isfield(headerStruct.stores.(varName), 'sortcode')
            headerStruct.stores.(varName).sortcode = cat(2,headerStruct.stores.(varName).sortcode{:});
        end
        if isfield(headerStruct.stores.(varName), 'data')
            if ~strcmp(headerStruct.stores.(varName).typeStr, 'epocs')
                if isfield(headerStruct.stores.(varName), 'data')
                    headerStruct.stores.(varName).data = cat(2,headerStruct.stores.(varName).data{:});
                end
            end
        end
        
        % if it's a data type, cast as a file offset pointer instead of data
        if strcmpi(headerStruct.stores.(varName).typeStr, 'streams') || ...
                strcmpi(headerStruct.stores.(varName).typeStr, 'snips')
            if isfield(headerStruct.stores.(varName), 'data')
                headerStruct.stores.(varName).data = typecast(headerStruct.stores.(varName).data, 'uint64');
            end
        end
        if isfield(headerStruct.stores.(varName), 'chan')
            if max(headerStruct.stores.(varName).chan) == 1
                headerStruct.stores.(varName).chan = 1;
            end
        end
        clear heads; % don't need this anymore
    end
end

if doHeadersOnly
    data = headerStruct;
    return;
end

% loop through all possible stores
storeNames = fields(headerStruct.stores);

if T2 > 0
    validTimeRange = [T1; T2];
else
    validTimeRange = [T1; Inf];
end

if ~isempty(RANGES)
    validTimeRange = RANGES;
end
numRanges = size(validTimeRange, 2);
if numRanges > 0
    data.time_ranges = validTimeRange;
end

% do full time filter here
for ii = 1:numel(storeNames)
    varName = storeNames{ii};
    if ~ismember(headerStruct.stores.(varName).typeNum, TYPE)
        continue
    end
    firstStart = validTimeRange(1,1);
    lastStop = validTimeRange(2,end);
    if isfield(headerStruct.stores.(varName), 'ts')
        filterInd = cell(1, numRanges);
        for jj = 1:numRanges
            start = validTimeRange(1,jj);
            stop = validTimeRange(2,jj);
            filterInd{jj} = find(headerStruct.stores.(varName).ts >= start & headerStruct.stores.(varName).ts < stop);
            if ~isempty(filterInd{jj})
                % parse out the information we need
                if strcmpi(headerStruct.stores.(varName).typeStr, 'streams')
                    % keep one prior for streams (for all channels)
                    nchan = max(headerStruct.stores.(varName).chan);
                    temp = filterInd{jj};
                    if temp(1)-nchan > 0
                        filterInd{jj} = [-(double(nchan:-1:1)) + temp(1) filterInd{jj}];
                    end
                    temp = headerStruct.stores.(varName).ts(filterInd{jj});
                    headerStruct.stores.(varName).startTime{jj} = temp(1);
                else
                    headerStruct.stores.(varName).filteredTS{jj} = headerStruct.stores.(varName).ts(filterInd{jj});
                end
                if isfield(headerStruct.stores.(varName), 'chan')
                    if numel(headerStruct.stores.(varName).chan) > 1
                        headerStruct.stores.(varName).filteredChan{jj} = headerStruct.stores.(varName).chan(filterInd{jj});
                    else
                        headerStruct.stores.(varName).filteredChan{jj} = headerStruct.stores.(varName).chan;
                    end
                end
                if isfield(headerStruct.stores.(varName), 'sortcode')
                    headerStruct.stores.(varName).filteredSortcode{jj} = headerStruct.stores.(varName).sortcode(filterInd{jj});
                end
                if isfield(headerStruct.stores.(varName), 'data')
                    headerStruct.stores.(varName).filteredData{jj} = headerStruct.stores.(varName).data(filterInd{jj});
                end
            end
        end
        if strcmpi(headerStruct.stores.(varName).typeStr, 'streams')
            headerStruct.stores.(varName) = rmfield(headerStruct.stores.(varName), 'ts');
            headerStruct.stores.(varName) = rmfield(headerStruct.stores.(varName), 'data');
            %if numel(headerStruct.stores.(varName).chan) > 1
            headerStruct.stores.(varName) = rmfield(headerStruct.stores.(varName), 'chan');   
        else
            % consolidate other fields
            headerStruct.stores.(varName).ts = [headerStruct.stores.(varName).filteredTS{:}];
            headerStruct.stores.(varName) = rmfield(headerStruct.stores.(varName), 'filteredTS');
            if isfield(headerStruct.stores.(varName), 'chan')
                headerStruct.stores.(varName).chan = [headerStruct.stores.(varName).filteredChan{:}];
                headerStruct.stores.(varName) = rmfield(headerStruct.stores.(varName), 'filteredChan');
            end
            if isfield(headerStruct.stores.(varName), 'sortcode')
                headerStruct.stores.(varName).sortcode = [headerStruct.stores.(varName).filteredSortcode{:}];
                headerStruct.stores.(varName) = rmfield(headerStruct.stores.(varName), 'filteredSortcode');
            end
            if isfield(headerStruct.stores.(varName), 'data')
                headerStruct.stores.(varName).data = [headerStruct.stores.(varName).filteredData{:}];
                headerStruct.stores.(varName) = rmfield(headerStruct.stores.(varName), 'filteredData');
            end
        end
    else
        % handle epoc events
        filterInd = cell(1, numRanges);
        for jj = 1:numRanges
            start = validTimeRange(1,jj);
            stop = validTimeRange(2,jj);
            filterInd{jj} = find(headerStruct.stores.(varName).onset >= start & headerStruct.stores.(varName).onset < stop);
        end
        
        filterInd = [filterInd{:}];
        if ~isempty(filterInd)
            headerStruct.stores.(varName).onset = headerStruct.stores.(varName).onset(filterInd);
            headerStruct.stores.(varName).data = headerStruct.stores.(varName).data(filterInd);
            headerStruct.stores.(varName).offset = headerStruct.stores.(varName).offset(filterInd);
            if strcmp(varName, 'Note')
                headerStruct.stores.(varName).notes = NoteText(filterInd);
            end
            % fix time ranges
            if headerStruct.stores.(varName).offset(1) < headerStruct.stores.(varName).onset(1)
                if headerStruct.stores.(varName).onset(1) > firstStart
                    headerStruct.stores.(varName).onset = [firstStart headerStruct.stores.(varName).onset];
                end
            end
            if headerStruct.stores.(varName).offset(end) > lastStop
                headerStruct.stores.(varName).offset(end) = lastStop;
            end
        else
            % default case is no valid events for this store
            headerStruct.stores.(varName).onset = [];
            headerStruct.stores.(varName).data = [];
            headerStruct.stores.(varName).offset = [];
            if strcmp(varName, 'Note')
                headerStruct.stores.(varName).notes = {};
            end
        end
    end
    
    % see if there are any notes to add
    [lia, loc] = ismember(headerStruct.stores.(varName).name, notes.name);
    if lia
        headerStruct.stores.(varName).notes = struct();
        ts = notes.ts{loc};
        noteInd = notes.index{loc};
        validInd = bitand(ts >= firstStart, ts < lastStop);
        headerStruct.stores.(varName).notes.ts = ts(validInd);
        headerStruct.stores.(varName).notes.index = noteInd(validInd);
        headerStruct.stores.(varName).notes.notes = noteStr(noteInd(validInd));
    end
end

for ii = 1:numel(storeNames)
    currentName = storeNames{ii};
    if ~ismember(headerStruct.stores.(currentName).typeNum, TYPE)
        continue
    end
    currentSize = headerStruct.stores.(currentName).size;
    currentTypeStr = headerStruct.stores.(currentName).typeStr;
    currentDForm = headerStruct.stores.(currentName).dform;
    if isfield(headerStruct.stores.(currentName), 'fs')
        currentFreq = headerStruct.stores.(currentName).fs;
    end
    
    % TODO: show similar verbose printout to TDT2mat
    fmt = 'unknown';
    sz = 4;
    switch currentDForm
        case DFORM_FLOAT
            fmt = 'single';
        case DFORM_LONG
            fmt = 'int32';
        case DFORM_SHORT
            fmt = 'int16';
            sz = 2;
        case DFORM_BYTE
            fmt = 'int8';
            sz = 1;
        case DFORM_DOUBLE
            fmt = 'double';
            sz = 8;
        case DFORM_QWORD
            fmt = 'int64';
            sz = 8;
    end
    
    % load data struct based on the type
    if isequal(currentTypeStr, 'epocs')
        headerStruct.stores.(currentName).data = headerStruct.stores.(currentName).data';
        headerStruct.stores.(currentName).onset = headerStruct.stores.(currentName).onset';
        headerStruct.stores.(currentName).offset = headerStruct.stores.(currentName).offset';
        if isfield(headerStruct.stores.(currentName), 'notes') && ~strcmp(currentName, 'Note')
            headerStruct.stores.(currentName).notes.notes = headerStruct.stores.(currentName).notes.notes';
            headerStruct.stores.(currentName).notes.index = headerStruct.stores.(currentName).notes.index';
            headerStruct.stores.(currentName).notes.ts = headerStruct.stores.(currentName).notes.ts';
        end
    elseif isequal(currentTypeStr, 'scalars')
        nchan = double(max(headerStruct.stores.(currentName).chan));
        if nchan > 1
            % organize data by sample
            ind = cell(1,nchan);
            for xx = 1:nchan
                ind{xx} = find(headerStruct.stores.(currentName).chan == xx);
            end
            if ~NODATA
                headerStruct.stores.(currentName).data = reshape(headerStruct.stores.(currentName).data([ind{:}]), [], nchan)';
            end
            
            % only use timestamps from first channel
            headerStruct.stores.(currentName).ts = headerStruct.stores.(currentName).ts(ind{xx});
            
            % remove channels field
            headerStruct.stores.(currentName) = rmfield(headerStruct.stores.(currentName),'chan');
        end
        if isfield(headerStruct.stores.(currentName), 'notes') && ~strcmp(currentName, 'Note')
            headerStruct.stores.(currentName).notes.notes = headerStruct.stores.(currentName).notes.notes';
            headerStruct.stores.(currentName).notes.index = headerStruct.stores.(currentName).notes.index';
            headerStruct.stores.(currentName).notes.ts = headerStruct.stores.(currentName).notes.ts';
        end
    elseif isequal(currentTypeStr, 'snips')
        
        headerStruct.stores.(currentName).name = currentName;
        headerStruct.stores.(currentName).fs = currentFreq;
        
        if CHANNEL > 0
            if numel(headerStruct.stores.(currentName).chan) == 1
                if CHANNEL == headerStruct.stores.(currentName).chan
                    % there is only one channel and we want it..
                else
                    error(['CHANNEL ' num2str(CHANNEL) ' not found']);
                end
            else
                validInd = headerStruct.stores.(currentName).chan == CHANNEL;
                if ~NODATA
                    allOffsets = double(headerStruct.stores.(currentName).data(validInd));
                end
                headerStruct.stores.(currentName).chan = headerStruct.stores.(currentName).chan(validInd);
                headerStruct.stores.(currentName).sortcode = headerStruct.stores.(currentName).sortcode(validInd);
                headerStruct.stores.(currentName).ts = headerStruct.stores.(currentName).ts(validInd);
            end
        else
            if ~NODATA
                allOffsets = double(headerStruct.stores.(currentName).data);
            end
        end
        
        headerStruct.stores.(currentName).chan = headerStruct.stores.(currentName).chan';
        headerStruct.stores.(currentName).sortcode = headerStruct.stores.(currentName).sortcode';
        headerStruct.stores.(currentName).ts = headerStruct.stores.(currentName).ts';
        
        if ~NODATA
            
            % try to optimally read data from disk in bigger chunks
            maxReadSize = 10000000;
            iter = 2048;
            arr = 1:iter:size(allOffsets,2);
            markers = allOffsets(arr);
            while numel(markers) > 1 && max(diff(markers)) > maxReadSize && iter > 1
                iter = max(iter / 2, 1);
                markers = allOffsets(1:iter:end);
            end
            arr = 1:iter:size(allOffsets,2);

            headerStruct.stores.(currentName).data = {};
            npts = (currentSize-10) * 4/sz;
            eventCount = 0;
            for f = 1:numel(arr)
                if fseek(tev, markers(f), 'bof') == -1
                    ferror(tev);
                end

                % do big-ish read
                if f == numel(arr)
                    readSize = (allOffsets(end) - markers(f))/sz + npts;
                else
                    readSize = (markers(f+1) - markers(f))/sz + npts;
                end
                readSize = double(readSize);
                tevData = fread(tev, readSize, ['*' fmt]);

                % we are covering these offsets
                start = arr(f);
                stop = min(arr(f)+iter-1, size(allOffsets,2));
                xxx = allOffsets(start:stop);

                % convert offsets from bytes to indices in data array
                relativeOffsets = (xxx - min(xxx))/sz + 1;
                ind = bsxfun(@plus, relativeOffsets', repmat(0:(double(npts)-1), numel(relativeOffsets), 1));

                % if we are missing data, there will be duplicates in the
                % ind array
                [uniqueVal,uniqueInd] = unique(ind(:,1));
                
                if numel(uniqueInd) ~= numel(ind(:,1))
                    % only keep uniques
                    ind = ind(uniqueInd, :);
                    % remove last row
                    ind = ind(1:end-1, :);
                    warning('data missing from TEV file for STORE:%s TIME:%.3fs', currentName, headerStruct.stores.(currentName).ts(eventCount + size(ind,1) + 1));
                    if isempty(ind)
                        continue
                    end
                end
                
                % add data to big cell array
                if min(size(ind)) == 1
                    % if there's only one event it's transposed
                    headerStruct.stores.(currentName).data{f} = tevData(ind)';
                    eventCount = eventCount + size(ind, 2);
                else
                    headerStruct.stores.(currentName).data{f} = tevData(ind);
                    eventCount = eventCount + size(ind, 1);
                end
            end
            % convert cell array for output
            headerStruct.stores.(currentName).data = cat(1,headerStruct.stores.(currentName).data{:});
            totalEvents = size(headerStruct.stores.(currentName).data,1);
            if numel(headerStruct.stores.(currentName).chan) > 1
                headerStruct.stores.(currentName).chan = headerStruct.stores.(currentName).chan(1:totalEvents);
            end
            headerStruct.stores.(currentName).sortcode = headerStruct.stores.(currentName).sortcode(1:totalEvents);
            headerStruct.stores.(currentName).ts = headerStruct.stores.(currentName).ts(1:totalEvents);
        end
    elseif isequal(currentTypeStr, 'streams')
        headerStruct.stores.(currentName).name = currentName;
        headerStruct.stores.(currentName).fs = currentFreq;
        
        % catch if the data is in SEV file
        sevList = dir([BLOCK_PATH '*.sev']);
        useSEVs = 0;
        for jj = 1:length(sevList)
            if strfind(sevList(jj).name, currentName) > 0
                useSEVs = 1;
                break
            end
        end
        
        if useSEVs
            
            % try to catch if sampling rate is wrong in SEV files
            expectedFS = 0;
            if ~isempty(fieldnames(blockNotes))
                [lia, loc] = ismember(headerStruct.stores.(currentName).name, {blockNotes(:).StoreName});
                if ~strcmp(blockNotes(loc).SampleFreq, '0')
                    expectedFS = str2double(blockNotes(loc).SampleFreq);
                end
            end
            if CHANNEL == 0
                d = SEV2mat(BLOCK_PATH, 'EVENTNAME', currentName, 'VERBOSE', 0, 'RANGES', validTimeRange, 'FS', expectedFS);
            else
                d = SEV2mat(BLOCK_PATH, 'EVENTNAME', currentName, 'CHANNEL', CHANNEL, 'VERBOSE', 0, 'RANGES', validTimeRange, 'FS', expectedFS);
            end
            detectedFS = d.(currentName).fs;
            if expectedFS > 0 && (abs(expectedFS - detectedFS) > 1)
                warning('Detected fs in SEV files was %.3f Hz, expected %.3f Hz. Using %.3f Hz.', detectedFS, expectedFS, expectedFS);
                d.(currentName).fs = expectedFS;
            end
            
            headerStruct.stores.(currentName) = d.(currentName);
            headerStruct.stores.(currentName).startTime = 0;
        else
            % make sure SEV files are there if they are supposed to be
            if headerStruct.stores.(currentName).ucf == 1
                warning('Expecting SEV files for %s but none were found, skipping...', currentName)
                continue
            end
            headerStruct.stores.(currentName).data = cell(1,numRanges);
            for jj = 1:numRanges
                fc = headerStruct.stores.(currentName).filteredChan{jj};
                if CHANNEL > 0
                    if all(headerStruct.stores.(currentName).filteredChan{jj} == 1)
                        % there is only one channel here, use them all
                        validInd = 1:numel(headerStruct.stores.(currentName).filteredData{jj});
                    else
                        validInd = fc == CHANNEL;
                        if ~any(validInd)
                            error('Channel %d not found in store %s', CHANNEL, currentName);
                        end
                        headerStruct.stores.(currentName).filteredChan{jj} = fc(validInd);    
                    end
                    nchan = 1;
                    chanIndex = 1;
                else
                    validInd = 1:numel(headerStruct.stores.(currentName).filteredData{jj});
                    nchan = double(max(fc));
                    chanIndex = ones(1,nchan);
                end
                
                fc = headerStruct.stores.(currentName).filteredChan{jj};
                theseOffsets = double(headerStruct.stores.(currentName).filteredData{jj});
                theseOffsets = theseOffsets(validInd);
                
                % preallocate data array
                npts = (currentSize-10) * 4/sz;
                headerStruct.stores.(currentName).data{jj} = zeros(nchan, npts*numel(theseOffsets)/nchan, fmt);
                
                % try to optimally read data from disk in bigger chunks
                maxReadSize = 10000000;
                iter = min(8192, size(theseOffsets,2)-1);
                arr = 1:iter:size(theseOffsets,2);
                markers = theseOffsets(arr);
                while max(diff(markers)) > maxReadSize
                    iter = floor(iter / 2);
                    markers = theseOffsets(1:iter:end);
                end
                arr = 1:iter:size(theseOffsets,2);
                
                channelOffset = 1;
                for f = 1:numel(arr)
                    if fseek(tev, markers(f), 'bof') == -1
                        ferror(tev);
                    end
                    
                    % do big-ish read
                    if f == numel(arr)
                        readSize = (theseOffsets(end) - markers(f))/sz + npts;
                    else
                        readSize = (markers(f+1) - markers(f))/sz + npts;
                    end
                    readSize = double(readSize);
                    tevData = fread(tev, readSize, ['*' fmt]);
                    
                    % we are covering these offsets
                    start = arr(f);
                    stop = min(arr(f)+iter-1, size(theseOffsets,2));
                    xxx = theseOffsets(start:stop);
                    
                    % convert offsets from bytes to indices in data array
                    relativeOffsets = (xxx - min(xxx))/sz + 1;
                    ind = bsxfun(@plus, relativeOffsets', repmat(0:(double(npts)-1), numel(relativeOffsets), 1));
                    
                    % loop through values, filling array
                    foundEmpty = false;
                    for kk = 1:numel(relativeOffsets)
                        if nchan > 1
                            chan = fc(channelOffset);
                        else
                            chan = 1;
                        end
                        channelOffset = channelOffset + 1;
                        if CHANNEL > 0
                            if isempty(find((ind(kk,:) <= numel(tevData)),1))
                                if ~foundEmpty
                                    warning('data missing from TEV file for STORE:%s CHANNEL:%d TIME:%.2fs', currentName, chan, T1 + chanIndex / headerStruct.stores.(currentName).fs)
                                    foundEmpty = true;
                                end
                                chanIndex = chanIndex + npts;
                                continue
                            end
                            foundEmpty = false;
                            headerStruct.stores.(currentName).data{jj}(1, chanIndex:(chanIndex + npts - 1)) = tevData(ind(kk,:))';
                            chanIndex = chanIndex + npts;
                        else
                            if isempty(find((ind(kk,:) <= numel(tevData)),1))
                                if ~foundEmpty
                                    warning('data missing from TEV file for STORE:%s CHANNEL:%d TIME:%.2fs', currentName, chan, T1 + chanIndex(chan) / headerStruct.stores.(currentName).fs)
                                    foundEmpty = true;
                                end
                                chanIndex(chan) = chanIndex(chan) + npts;
                                continue
                            end
                            foundEmpty = false;
                            headerStruct.stores.(currentName).data{jj}(chan, chanIndex(chan):chanIndex(chan) + npts - 1) = tevData(ind(kk,:));
                            chanIndex(chan) = chanIndex(chan) + npts;
                        end
                    end
                    % add data to big cell array
                end
                % convert cell array for output
                % be more exact with streams time range filter.
                % keep timestamps >= validTimeRange(1) and < validTimeRange(2)
                % index 1 is at headerStruct.stores.(currentName).startTime
                minSample = max(ceil((validTimeRange(1,jj)-headerStruct.stores.(currentName).startTime{jj})*headerStruct.stores.(currentName).fs),0)+1;
                maxSample = min(max(floor((validTimeRange(2,jj)-headerStruct.stores.(currentName).startTime{jj})*headerStruct.stores.(currentName).fs),0)+1, size(headerStruct.stores.(currentName).data{jj}, 2));
                headerStruct.stores.(currentName).data{jj} = headerStruct.stores.(currentName).data{jj}(:,minSample:maxSample);
                headerStruct.stores.(currentName).startTime{jj} = headerStruct.stores.(currentName).startTime{jj} + (minSample-1) / headerStruct.stores.(currentName).fs;
            end
            if CHANNEL > 0
                headerStruct.stores.(currentName).channel = CHANNEL;
            end
            headerStruct.stores.(currentName) = rmfield(headerStruct.stores.(currentName), 'filteredChan');
            headerStruct.stores.(currentName) = rmfield(headerStruct.stores.(currentName), 'filteredData');
        end
        if numel(headerStruct.stores.(currentName).data) == 1
            headerStruct.stores.(currentName).data = [headerStruct.stores.(currentName).data{1}];
            headerStruct.stores.(currentName).startTime = [headerStruct.stores.(currentName).startTime{1}];
        end
    end
    data.(currentTypeStr).(currentName) = headerStruct.stores.(currentName);
end

if ~isempty(COMBINE)
    for ii = 1:numel(COMBINE)
        if ~isfield(data.snips, COMBINE{ii})
            error(['Specified COMBINE store name ' COMBINE{ii} ' is not in snips']);
        end
        data.snips.(COMBINE{ii}) = snip_maker(data.snips.(COMBINE{ii}));
    end
end
    
if ~strcmp(BITWISE , '')
    if ~(isfield(data.epocs, BITWISE) || isfield(data.scalars, BITWISE))
        error(['Specified BITWISE store name ' BITWISE ' is not in epocs or scalars']);
    end
    
    nbits = 32;
    if isfield(data.epocs, BITWISE)
        bitwisetype = 'epocs';
    else
        bitwisetype = 'scalars';
    end
    
    if ~isfield(data.(bitwisetype).(BITWISE), 'data')
        error('data field not found')
    end
    
    % create big array of all states
    sz = numel(data.(bitwisetype).(BITWISE).data);
    big_array = zeros(nbits+1, sz);
    if strcmpi(bitwisetype, 'epocs')
        big_array(1,:) = data.(bitwisetype).(BITWISE).onset;
    else
        big_array(1,:) = data.(bitwisetype).(BITWISE).ts;
    end
    
    data.(bitwisetype).(BITWISE).bitwise = struct();
    
    % loop through all states
    prev_state = zeros(32,1);
    for i = 1:sz
        xxx = typecast(int32(data.(bitwisetype).(BITWISE).data(i)), 'uint32');
        bbb = dec2bin(xxx(1), 32);
        curr_state = str2num(bbb');          %#ok<ST2NM>
        big_array(2:nbits+1,i) = curr_state;
            
        % look for changes from previous state
        changes = find(xor(prev_state, curr_state));
        
        % add timestamp to onset or offset depending on type of state change
        for j = 1:numel(changes)
            ind = changes(j);
            ffield = ['bit' num2str(nbits-ind)];
            if bbb(ind) == '1'
                % nbits-ind reverses it so b0 is bbb(end)
                if isfield(data.(bitwisetype).(BITWISE).bitwise, ffield)
                    data.(bitwisetype).(BITWISE).bitwise.(ffield).onset = [data.(bitwisetype).(BITWISE).bitwise.(ffield).onset big_array(1,i)];
                else
                    data.(bitwisetype).(BITWISE).bitwise.(ffield).onset = big_array(1,i);
                    data.(bitwisetype).(BITWISE).bitwise.(ffield).offset = [];
                end
            else
                data.(bitwisetype).(BITWISE).bitwise.(ffield).offset = [data.(bitwisetype).(BITWISE).bitwise.(ffield).offset big_array(1,i)];
            end
        end
        prev_state = curr_state;
   end
        
   % add 'inf' to offsets that need them
   for i = 0:nbits-1
       ffield = ['bit' num2str(i)];
       if isfield(data.(bitwisetype).(BITWISE).bitwise, ffield)
           if numel(data.(bitwisetype).(BITWISE).bitwise.(ffield).onset) - 1 == numel(data.(bitwisetype).(BITWISE).bitwise.(ffield).offset)
               data.(bitwisetype).(BITWISE).bitwise.(ffield).offset = [data.(bitwisetype).(BITWISE).bitwise.(ffield).offset inf];
           end
       end
   end
end

if ~useOutsideHeaders
    if (tsq), fclose(tsq); end
end
if (tev), fclose(tev); end
end

function t = epoc2type(code)
%% given epoc event code, return if it is 'onset' or 'offset' event

global EVTYPE_STRON EVTYPE_STROFF EVTYPE_MARK;

strobeOnTypes = [EVTYPE_STRON EVTYPE_MARK];
strobeOffTypes = [EVTYPE_STROFF];
t = 'unknown';
if ismember(code, strobeOnTypes)
    t = 'onset';
elseif ismember(code, strobeOffTypes)
    t = 'offset';
end
end

function s = code2type(code)
%% given event code, return string 'epocs', 'snips', 'streams', or 'scalars'

global EVTYPE_STRON EVTYPE_STROFF EVTYPE_SCALAR EVTYPE_SNIP EVTYPE_MARK EVTYPE_MASK EVTYPE_STREAM;

strobeTypes = [EVTYPE_STRON EVTYPE_STROFF EVTYPE_MARK];
scalarTypes = [EVTYPE_SCALAR];
snipTypes = [EVTYPE_SNIP];

if ismember(code, strobeTypes)
    s = 'epocs';
elseif ismember(code, snipTypes)
    s = 'snips';
elseif bitand(code, EVTYPE_MASK) == EVTYPE_STREAM
    s = 'streams';
elseif ismember(code, scalarTypes)
    s = 'scalars';
else
    s = 'unknown';
end
end

function s = checkUCF(code)
    %% given event code, return string 'epocs', 'snips', 'streams', or 'scalars'
    global EVTYPE_UCF
    s = bitand(code, EVTYPE_UCF) == EVTYPE_UCF;
end

function varname = fixVarName(name, varargin)
if nargin == 1
    VERBOSE = 0;
else
    VERBOSE = varargin{1};
end
varname = name;
for ii = 1:numel(varname)
    if ii == 1
        if isstrprop(varname(ii), 'digit')
            varname(ii) = 'x';
        end
    end
    if ~isstrprop(varname(ii), 'alphanum')
        varname(ii) = '_';
    end
end
%TODO: use this instead in 2014+
%varname = matlab.lang.makeValidName(name);
if ~isvarname(name) && VERBOSE
    fprintf('info: %s is not a valid Matlab variable name, changing to %s\n', name, varname);
end
end

function blockNotes = parseTBK(tbkPath)

blockNotes = struct();
tbk = fopen(tbkPath, 'rb');
if tbk < 0
    warning('TBK file %s not found', tbkPath);
    return
end

s = fread(tbk, inf, '*char')';
fclose(tbk);

% create array of structs with store information %
% split block notes into rows
delimInd = strfind(s, '[USERNOTEDELIMITER]');
try
    s = s(delimInd(2):delimInd(3));
catch
    warning('Bad TBK file, try running the TankRestore tool to correct. See http://www.tdt.com/technotes/#0935.htm')
    return;
end
lines = textscan(s, '%s', 'delimiter', sprintf('\n'));
lines = lines{1};

% loop through rows
storenum = 0;
for i = 1:length(lines)-1
    
    % check if this is a new store
    if(~isempty(strfind(lines{i},'StoreName')))
        storenum = storenum + 1;
    end
    
    % find delimiters
    equals = strfind(lines{i},'=');
    semi = strfind(lines{i},';');
    
    % grab field and value between the '=' and ';'
    fieldstr = lines{i}(equals(1)+1:semi(1)-1);
    value = lines{i}(equals(3)+1:semi(3)-1);
    
    % insert new field and value into store struct
    blockNotes(storenum).(fieldstr) = value;
end

% print out store information
% for i = 1:storenum
%     temp = blockNotes(i);
%     disp(temp.StoreName)
%     if strcmp(temp.Enabled, '2')
%         disp([temp.StoreName ' STORE DISABLED'])
%     end
% end
end

function data_snip = snip_maker(data_snip)
% convert strobe-controlled data snips into larger chunks
ts_diffs = diff(data_snip.ts); 
ts_diffThresh = (size(data_snip.data,2)+1) / data_snip.fs;
gap_points = find(ts_diffs > ts_diffThresh);
gap_points = [gap_points; size(data_snip.data,1)];
chunk_length = size(data_snip.data, 2);

snip_store = cell(numel(gap_points), 1);
snip_store_ts = zeros(numel(gap_points), 1);
nchan = double(max(data_snip.chan));
gp_index = 1;

for ind = 1:numel(gap_points)
    if nchan == 1
        chan_index = 1:(gap_points(ind) - gp_index + 1);
        snip_store{ind} = reshape(data_snip.data(gp_index + chan_index-1,:)', 1, []);
    else
        nchunks = floor((gap_points(ind) - gp_index + 1) / nchan);
        chan_mat = zeros(nchan, nchunks * chunk_length);
        for chan = 1:nchan
            chan_index = find(data_snip.chan(gp_index:gap_points(ind)) == chan);
            if length(chan_index) ~= nchunks
                warning('Channel %d was shortened to %d chunks', chan, nchunks);
            end
            chan_index = chan_index(1:nchunks);
            chan_mat(chan,:) = reshape(data_snip.data(gp_index + chan_index-1,:)', 1, []);
        end
        snip_store{ind} = chan_mat;
    end
    snip_store_ts(ind) = data_snip.ts(gp_index);
    gp_index = gap_points(ind)+1;
end

data_snip.data = snip_store;
data_snip.ts = snip_store_ts;
data_snip.chan = (1:max(data_snip.chan))';
end