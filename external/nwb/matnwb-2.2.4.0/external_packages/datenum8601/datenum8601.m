function [DtN,Spl,TkC] = datenum8601(Str,Tok)
% Convert an ISO 8601 formatted Date String (timestamp) to a Serial Date Number.
%
% (c) 2015 Stephen Cobeldick
%
% ### Function ###
%
% Syntax:
%  DtN = datenum8601(Str)
%  DtN = datenum8601(Str,Tok)
%  [DtN,Spl,TkC] = datenum8601(...)
%
% By default the function automatically detects all ISO 8601 timestamp/s in
% the string, or use a token to restrict detection to only one particular style.
%
% The ISO 8601 timestamp style options are:
% - Date in calendar, ordinal or week-numbering notation.
% - Basic or extended format.
% - Choice of date-time separator character ( @T_).
% - Full or lower precision (trailing units omitted)
% - Decimal fraction of the trailing unit.
% These style options are illustrated in the tables below.
%
% The function returns the Serial Date Numbers of the date and time given
% by the ISO 8601 style timestamp/s, the input string parts that are split
% by the detected timestamps (i.e. the substrings not part of  any ISO 8601
% timestamp), and string token/s that define the detected timestamp style/s.
%
% Note 1: Calls undocumented MATLAB function "datenummx".
% Note 2: Unspecified month/date/week/day timestamp values default to one (1).
% Note 3: Unspecified hour/minute/second timestamp values default to zero (0).
% Note 4: Auto-detection mode also parses mixed basic/extended timestamps.
%
% See also DATESTR8601 DATEROUND CLOCK NOW DATENUM DATEVEC DATESTR NATSORT NATSORTROWS NATSORTFILES
%
% ### Examples ###
%
% Examples use the date+time described by the vector [1999,1,3,15,6,48.0568].
%
% datenum8601('1999-01-03 15:06:48.0568')
%  ans = 730123.62972287962
%
% datenum8601('1999003T150648.0568')
%  ans = 730123.62972287962
%
% datenum8601('1998W537_150648.0568')
%  ans = 730123.62972287962
%
% [DtN,Spl,TkC] = datenum8601('A19990103B1999-003C1998-W53-7D')
%  DtN = [730123,730123,730123]
%  Spl = {'A','B','C','D'}
%  TkC = {'ymd','*yn','*YWD'}
%
% [DtN,Spl,TkC] = datenum8601('1999-003T15')
%  DtN = 730123.6250
%  Spl = {'',''}
%  TkC = {'*ynTH'}
%
% [DtN,Spl,TkC] = datenum8601('1999-01-03T15','*ymd')
%  DtN = 730123.0000
%  Spl = {'','T15'}
%  TkC = {'*ymd'}
%
% ### ISO 8601 Timestamps ###
%
% The token consists of one letter for each of the consecutive date/time
% units in the timestamp, thus it defines the date notation (calendar,
% ordinal or week-date) and selects either basic or extended format:
%
% Input    | Basic Format             | Extended Format (token prefix '*')
% Date     | In/Out | Input Timestamp | In/Out  | Input Timestamp
% Notation:| <Tok>: | <Str> Example:  | <Tok>:  | <Str> Example:
% =========|========|=================|=========|===========================
% Calendar |'ymdHMS'|'19990103T150648'|'*ymdHMS'|'1999-01-03T15:06:48'
% ---------|--------|-----------------|---------|---------------------------
% Ordinal  |'ynHMS' |'1999003T150648' |'*ynHMS' |'1999-003T15:06:48'
% ---------|--------|-----------------|---------|---------------------------
% Week     |'YWDHMS'|'1998W537T150648'|'*YWDHMS'|'1998-W53-7T15:06:48'
% ---------|--------|-----------------|---------|---------------------------
%
% Options for reduced precision timestamps, non-standard date-time separator
% character, and the addition of a decimal fraction of the trailing unit:
%
% Omit trailing units (reduced precision), eg:                    | Output->Vector:
% =========|========|=================|=========|=================|=====================
%          |'Y'     |'1999W'          |'*Y'     |'1999-W'         |[1999,1,4,0,0,0]
% ---------|--------|-----------------|---------|-----------------|---------------------
%          |'ymdH'  |'19990103T15'    |'*ymdH'  |'1999-01-03T15'  |[1999,1,3,15,0,0]
% ---------|--------|-----------------|---------|-----------------|---------------------
% Select the date-time separator character (one of ' ','@','T','_'), eg:
% =========|========|=================|=========|=================|=====================
%          |'yn_HM' |'1999003_1506'   |'*yn_HM' |'1999-003_15:06' |[1999,1,3,15,6,0]
% ---------|--------|-----------------|---------|-----------------|---------------------
%          |'YWD@H' |'1998W537@15'    |'*YWD@H' |'1998-W53-7@15'  |[1999,1,3,15,0,0]
% ---------|--------|-----------------|---------|-----------------|---------------------
% Decimal fraction of trailing date/time value, eg:
% =========|========|=================|=========|=================|=====================
%          |'ynH3'  |'1999003T15.113' |'*ynH3'  |'1999-003T15.113'|[1999,1,3,15,6,46.80]
% ---------|--------|-----------------|---------|-----------------|---------------------
%          |'YWD4'  |'1998W537.6297'  |'*YWD4'  |'1998-W53-7.6297'|[1999,1,3,15,6,46.08]
% ---------|--------|-----------------|---------|-----------------|---------------------
%          |'y10'   |'1999.0072047202'|'*y10'   |'1999.0072047202'|[1999,1,3,15,6,48.06]
% ---------|--------|-----------------|---------|-----------------|---------------------
%
% Note 5: This function does not check for ISO 8601 compliance: user beware!
% Note 6: Date-time separator character must be one of ' ','@','T','_'.
% Note 7: Date notations cannot be combined: note upper/lower case characters.
%
% ### Input & Output Arguments ###
%
% Inputs (*default):
%  Str = DateString, possibly containing one or more ISO 8601 dates/timestamps.
%  Tok = String, token to select the required date notation and format (*[]=any).
%
% Outputs:
%  DtN = NumericVector of Serial Date Numbers, one from each timestamp in input <Str>.
%  Spl = CellOfStrings, the strings before, between and after the detected timestamps.
%  TkC = CellOfStrings, tokens of each timestamp notation and format (see tables).
%
% [DtN,Spl,TkC] = datenum8601(Str,*Tok)

% Define "regexp" match string:
if nargin<2 || isempty(Tok)
    % Automagically detect timestamp style.
    MtE = [...
        '(\d{4})',... % year
        '((-(?=(\d{2,3}|W)))?)',... % -
        '(W?)',...    % W
        '(?(3)(\d{2})?|(\d{2}(?=($|\D|\d{2})))?)',... % week/month
        '(?(4)(-(?=(?(3)\d|\d{2})))?)',...   % -
        '(?(4)(?(3)\d|\d{2})?|(\d{3})?)',... % day of week/month/year
        '(?(6)([ @T_](?=\d{2}))?)',... % date-time separator character
        '(?(7)(\d{2})?)',...  % hour
        '(?(8)(:(?=\d{2}))?)',...  % :
        '(?(8)(\d{2})?)',...  % minute
        '(?(10)(:(?=\d{2}))?)',... % :
        '(?(10)(\d{2})?)',... % second
        '((\.\d+)?)']; % trailing unit decimal fraction
    % (Note: allows a mix of basic/extended formats)
else
    % User requests a specific timestamp style.
    assert(ischar(Tok)&&isrow(Tok),'Second input <Tok> must be a string.')
    TkU = regexp(Tok,'(^\*?)([ymdnYWD]*)([ @T_]?)([HMS]*)(\d*$)','tokens','once');
    assert(~isempty(TkU),'Second input <Tok> is not supported: ''%s''',Tok)
    MtE = [TkU{2},TkU{4}];
    TkL = numel(MtE);
    Ntn = find(strncmp(MtE,{'ymdHMS','ynHMS','YWDHMS'},TkL),1,'first');
    assert(~isempty(Ntn),'Second input <Tok> is not supported: ''%s''',Tok)
    MtE = dn8601Usr(TkU,TkL,Ntn);
end
%
assert(ischar(Str)&&size(Str,1)<2,'First input <Str> must be a string.')
%
% Extract timestamp tokens, return split strings:
[TkC,Spl] = regexp(Str,MtE,'tokens','split');
%
[DtN,TkC] = cellfun(@dn8601Main,TkC);
%
end
%----------------------------------------------------------------------END:datenum8601
function [DtN,Tok] = dn8601Main(TkC)
% Convert detected substrings into serial date number, create string token.
%
% Lengths of matched tokens:
TkL = cellfun('length',TkC);
% Preallocate Date Vector:
DtV = [1,1,1,0,0,0];
%
% Create token:
Ext = '*';
Sep = [TkC{7},'HMS'];
TkX = {['ymd',Sep],['y*n',Sep],['YWD',Sep]};
Ntn = 1+(TkL(6)==3)+2*TkL(3);
Tok = [Ext(1:+any(TkL([2,5,9,11])==1)),TkX{Ntn}(0<TkL([1,4,6,7,8,10,12]))];
%
% Convert date and time values to numeric:
Idx = [1,4,6,8,10,12];
for m = find(TkL(Idx));
    DtV(m) = sscanf(TkC{Idx(m)},'%f');
end
% Add decimal fraction of trailing unit:
if TkL(13)>1
    if Ntn==2&&m==2 % Month (special case not converted by "datenummx"):
        DtV(3) = 1+sscanf(TkC{13},'%f')*(datenummx(DtV+[0,1,0,0,0,0])-datenummx(DtV));
    else % All other date or time values (are converted by "datenummx"):
        DtV(m) = DtV(m)+sscanf(TkC{13},'%f');
    end
    Tok = {[Tok,sprintf('%.0f',TkL(13)-1)]};
else
    Tok = {Tok};
end
%
% Week-numbering vector to ordinal vector:
if Ntn==3
    DtV(3) = DtV(3)+7*DtV(2)-4-mod(datenummx([DtV(1),1,1]),7);
    DtV(2) = 1;
end
% Convert out-of-range Date Vector to Serial Date Number:
DtN = datenummx(DtV) - 31*(0==DtV(2));
% (Month zero is a special case not converted by "datenummx")
%
end
%----------------------------------------------------------------------END:dn8601Main
function MtE = dn8601Usr(TkU,TkL,Ntn)
% Create "regexp" <match> string from user input token.
%
% Decimal fraction:
if isempty(TkU{5})
    MtE{13} = '()';
else
    MtE{13} = ['(\.\d{',TkU{5},'})'];
end
% Date-time separator character:
if isempty(TkU{3})
    MtE{7} = '(T)';
else
    MtE{7} = ['(',TkU{3},')'];
end
% Year and time tokens (year, hour, minute, second):
MtE([1,8,10,12]) = {'(\d{4})','(\d{2})','(\d{2})','(\d{2})'};
% Format tokens:
if isempty(TkU{1}) % Basic
    MtE([2,5,9,11]) = {'()','()','()','()'};
else % Extended
    MtE([2,5,9,11]) = {'(-)','(-)','(:)','(:)'};
end
% Date tokens:
switch Ntn
    case 1 % Calendar
        Idx = [2,5,7,9,11,13];
        MtE([3,4,6]) = {'()', '(\d{2})','(\d{2})'};
    case 2 % Ordinal
        Idx = [2,7,9,11,13];
        MtE([3,4,5,6]) = {'()','()','()','(\d{3})'};
    case 3 % Week
        Idx = [2,5,7,9,11,13];
        MtE([3,4,6]) = {'(W)','(\d{2})','(\d{1})'};
end
%
% Concatenate tokens into "regexp" match token:
MtE(Idx(TkL):12) = {'()'};
MtE = [MtE{:}];
%
end
%----------------------------------------------------------------------END:dn8601Usr