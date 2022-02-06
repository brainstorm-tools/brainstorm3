function [A,ffn,num_header,sr_input_ca,hl,fpos] = txt2mat(varargin)

% TXT2MAT read an ascii file and convert a data table to matrix
%
% Syntax:
%  A = txt2mat
%  A = txt2mat(fn)
%  [A,ffn,nh,SR,hl,fpos] = txt2mat(fn,nh,nc,cstr,SR,SX)
%  [A,ffn,nh,SR,hl,fpos] = txt2mat(fn,... 'param',value,...)
%
% with
%
% A     output data matrix
% ffn   full file name
% nh    number of header lines
% hl    header lines (as a string)
% fpos  file position of last character read and converted from ascii file
%
% fn    file or path name ('*' is allowed as wildcard in file name)
% nh    number of header lines
% nc    number of data columns
% cstr  conversion string
% SR    cell array of replacement strings  sr<i>, SR = {sr1,sr2,...}
% SX    cell array of invalid line strings sx<i>, SX = {sx1,sx2,...}
%
% All input arguments are optional. See below for param/value-pairs.
%
% TXT2MAT reads the ascii file <fn> and extracts the values found in a 
% data table with <nc> columns to a matrix, skipping <nh> header lines. 
% When extracting the data, <cstr> is used as conversion type specifier for
% each line (see sscanf online doc for conversion specifiers). 
%
% If <fn> is an existing directory, or contains an asterisk wildcard in the
% file name, or is an empty string, a file selection dialogue is displayed.
%
% Additional strings <sr1>,<sr2>,.. can be supplied within a cell array
% <SR> to perform single character substitution before the data is
% converted: each of the first n-1 characters of an <n> character string is
% replaced by the <n>-th character.
%
% A further optional input argument is a cell array <SX> containing strings
% <sx1>,<sx2>,.. that mark "bad" lines containing invalid data. If every
% line containing invalid data can be caught by the <SX>, TXT2MAT will
% speed up significantly (see EXAMPLE 3a). Any lines that are recognized to
% be invalid are completely ignored (and there is no corresponding row in
% A). 
%
% If the number of header lines <nh> or the number of data columns <nc> are
% not provided, TXT2MAT performs some automatic analysis of the file format.
% This will need the numbers in the file to be decimals (with decimal point
% or comma) and the data arrangement to be more or less regular (see also
% remark 1). 
% If <nc> is negative, TXT2MAT internally initializes the output matrix <A>
% with |<nc>| columns, but allows for expanding <A> if more numeric values
% are found in any line of the file. To this end, TXT2MAT is forced to
% switch to line by line conversion.
%
% If some lines of the data table can not be (fully) converted, the
% corresponding rows in A are padded with NaNs. 
%
% For further options and to facilitate the argument assignment, the
% param/value-notation can be used instead of the single argument syntax
% txt2mat(ffn,nh,nc,cstr,SR,SX)
% The following table lists the param/value-pairs and their corresponding
% single argument, if existing:
%
%  Param-string      Value type  Example value                  single arg.
%  'NumHeaderLines'  Scalar      13                                      nh
%  'NumColumns'      Scalar      9                                       nc
%  'ConvString'      String      ['%d.%d.%d' repmat('%f',1,6)]         cstr
%  'ReplaceChar'     Cell        {')Rx ',';: '}                          SR    
%  'BadLineString'   Cell        {'Warng', 'Bad'}                        SX     
%  'GoodLineString'  Cell        {'2009-08-17'}                           -
%  'ReplaceExpr'     Cell        {{'True','1'},{'#NaN','#Inf','NaN'}}     -
%  'ReplaceRegExpr'  Cell        {{';\s*(?=;)','; NaN'}}                  -
%  'DialogString'    String      'Now choose a log file'                  -
%  'InfoLevel'       Scalar      1                                        -
%  'ReadMode'        String      'auto'                                   -
%  'NumericType'     String      'single'                                 -
%  'RowRange'        2x1-Vector  [2501 5000]                              -
%  'FilePos'         Scalar      0                                        -
%  'MemPar'          Scalar      2^17                                     -
%
% The param/value-pairs may follow the usual arguments in any order, e.g.
% txt2mat('file.txt',13,9,'BadLineString',{'Bad'},'ConvString','%f'). Only
% the single file name argument must be given as the first input.
%
% Param/value-pairs with additional functionality:
%
% · 'GoodLineString': ignore all lines that do not contain at least one of
%   the strings in the cell array (see EXAMPLE 3b).
%
% · The 'ReplaceExpr' argument works similar to the 'ReplaceChar' argument.
%   It just replaces whole expressions instead of single characters. A cell
%   array containing at least one cell array of strings must be provided.
%   Such a cell array of strings consists of <n> strings, each of the first
%   <n-1> strings is replaced by the <n>-th string. For example, with
%   {{'R1a','R1b, 'S1'}, {'R2a','R2b','R2c', 'S2'}}
%   all the 'R<n>'-strings are replaced by the corresponding 'S<n>' string.
%   In general, replacing whole strings takes more time than 'ReplaceChar',
%   especially if the strings differ in size.
%   Expression replacements are performed before character replacements.
%
% · By the help of the 'ReplaceRegExpr' argument regular expressions can be
%   replaced. The usage is analogous to 'ReplaceExpr'. Regular expression
%   replacements are carried out before any other replacement (see 
%   EXAMPLE 5).
%
% · The 'DialogString' argument provides the text shown in the title bar of
%   the file selection dialogue that may appear.
%
% · The 'InfoLevel' argument controls the verbosity of TXT2MAT's outputs in
%   the command window and the message boxes. Currently known values are: 
%   0, 1, 2 (default)
%
% · 'ReadMode' is one of 'matrix', 'line', 'auto' (default), or 'block'. 
%   'matrix': Read and convert sections of multiple lines simultaneously, 
%             requiring each line to contain the same number of values.
%             Finding an improper number of values in such a section will
%             cause an error (see also remark 2).
%   'line':   Read and convert text line by line, allowing different
%             numbers of values per line (slower than 'matrix' mode).
%   'auto':   Try 'matrix' first, continue with 'line' if an error occurs.
%   'block':  Read and convert sections of multiple lines simultaneously
%             and fill up the data matrix regardless of how many values
%             occur in each text line. Only a warning is issued if a
%             section's number of values is not a multiple of the number of
%             columns of the output data matrix. This is the fastest mode.
%
% · 'NumericType' is one of 'int8', 'int16', 'int32', 'int64', 'uint8',
%   'uint16', 'uint32', 'uint64', 'single', or 'double' (default),
%   determining the numeric class of the output matrix A. If the numeric
%   class does not support NaNs, missing elements are padded with zeros
%   instead. Reduce memory  consumption by choosing an appropriate numeric
%   class, if needed. 
% 
% · The 'RowRange' value is a sorted positive integer two element vector
%   defining an interval of data rows to be converted (header lines do not
%   count, but lines that will be recognized as invalid - see above - do). 
%   If the vector's second element exceeds the number of valid data rows in
%   the file, the data is extracted up to the end of the file (Inf is
%   allowed as second argument). It may save memory and computation time if
%   only a small part of data has to be extracted from a huge text file. 
% 
% · The 'FilePos' value <fp> is a nonnegative integer scalar. <fp>
%   characters from the beginning of the file will be ignored, i.e. not be
%   read. If you run TXT2MAT with a 'RowRange' argument, you may
%   use the <fpos> output as an 'FilePos' input during the next run in
%   order to continue from where you stopped. By that you can split up the
%   conversion process e.g. when the file is too big to be read as a whole
%   (see EXAMPLE 6). 
% 
% · The 'MemPar' argument provides the minimum amount of characters TXT2MAT
%   will process simultaneously as an internal text section (= a set of
%   text lines). It must be a positive integer. The value does not affect
%   the outputs, but computation time and memory usage. The roughly
%   optimized default is 65536; usually there is no need to change it. 
%
% -------------------------------------------------------------------------
%
% REMARKS
%
% 1) prerequisites for the automatic file format analysis (if the number of
%    header lines and data columns is not given):
%    · header lines can be detected by either non-numeric characters or
%      a strongly deviating number of numeric items in relation to the
%      data section (<10%)
%    · tab, space, slash, comma, colon, and semicolon are accepted as
%      delimiters (e.g. "10/11/2006 08:30 1; 3.3; 0.52" is ok)
%    · after the optional user supplied replacements have been carried out,
%      the data section must contain the delimiters and the decimal numbers 
%      only (point or comma are accepted as decimal character).
%    Note: if you do not trigger the internal file format analysis, i.e.
%    you do provide both the number of header lines and the number of data
%    columns, you also have to care for an eventual decimal _comma_ and
%    non-whitespace delimiters. Such a comma can be replaced with a '.',
%    and the whitespaces can either be included into a suitable conversion
%    string or be replaced with whitespaces (see e.g. the 'ReplaceChar'
%    argument)  
% 
% 2) In matrix mode, txt2mat checks that the conversion string is suitable
%    and that the number of values read from a section of the file is the
%    product of the number of text lines and the number of columns. This
%    may be true even if the number of values per line is not uniform and
%    txt2mat may be misled. So using matrix mode you should be sure that
%    all lines that can't be sorted out by a bad line marker string contain
%    the same number of values.
%
% 3) Since txt2mat.m is a comparatively large file, generating a preparsed
%    file txt2mat.p once will speed up the first call during a matlab
%    session. Set the current directory to where you saved txt2mat.m and
%    type
%    >> pcode txt2mat
%    For further information, see the 'pcode' documentation.
%
% -------------------------------------------------------------------------
%
% EXAMPLE 1:
%
% A = txt2mat;      % choose a file and let TXT2MAT analyse its format
%                 
% -------------------------------------------------------------------------
%
% EXAMPLE 2:
%
% Supposed your ascii file C:\mydata.log contains the following lines: 
% »
% 10 11 2006 08 35.225 1  3.3  0.52
% 31 05 2008 12 12     0  0.0  0.00
%  7 01 2010 15 23.5  -1  3.3  0.535
% «
% type
%
% A = txt2mat('C:\mydata.log',0,8);
%
% or just
%
% A = txt2mat('C:\mydata.log');
%
% Here, TXT2MAT uses its automatic file layout detection as the header line
% and column number is not given. With the file looking like this:
% » 
% some example data
% plus another header line
% 10/11/2006 08:35,225 1; 3,3; 0,52
% 31/05/2008 12:12     0; 0,0; 0,00
% 7/01/2010  15:23,5  -1; 3,3; 0,535
% «
% txt2mat('C:\mydata.log') returns the same output data matrix as above.
%
% -------------------------------------------------------------------------
%
% EXAMPLE 3a:
%
% Supposed your ascii file C:\mydata.log starts as follows:
% »
% ;$FILEVERSION=1.1
% ;$STARTTIME=38546.6741619815
% ;---+--   ----+----  --+--  ----+---  +  -+ -- -- -- 
%      3)         7,2  Rx         0300  8  01 A3 58 4D 
%      4)         7,3  Rx         0310  8  06 6E 2B 9F 
%      5)         9,5  Warng  FFFFFFFF  4  00 00 00 08  BUSHEAVY 
%      6)        12,9  Rx         0320  8  02 E1 F6 EF 
% «
% you may specify 
% nh   = 3          % header lines, 
% nc   = 12         % data columns,
% cstr = '%f %f %x %x %x %x %x %x'  % as conversion string for floats and
%                                   % hexadecimals,  
% sr1  = ')Rx '     % as first replacement string to blank the characters
%                     ')','R', and 'x' (if you don't want to include them
%                     in the conversion string), and
% sr2  = ',.'       % to replace the decimal comma with a dot, and
% sx1  = 'Warng'    % as a marker for invalid lines
%
% A = txt2mat('C:\mydata.log', nh, nc, cstr, {sr1,sr2}, {'Warng'});
%
%   A =
% 		3    7.2    768      8      1    163     88     77
% 		4    7.3    784      8      6    110     43    159
% 		6   12.9    800      8      2    225    246    239
% 		...
% 
% If you make use of the param/value-pairs, you can also write more clearly
%
% t2mOpts = {'NumHeaderLines', 3                         , ...
%            'NumColumns'    , 12                        , ...
%            'ReplaceChar'   , {')Rx ',',.'}             , ...
%            'ConvString'    , '%f %f %x %x %x %x %x %x' , ...
%            'BadLineString' , {'Warng'}                    };
%        
% A = txt2mat('C:\mydata.log', t2mOpts{:});
% 
% Without the {'Warng'} argument, A would have been
%
% 		3    7.2    768      8      1    163     88     77
% 		4    7.3    784      8      6    110     43    159
% 		5    9.5    NaN    NaN    NaN    NaN    NaN    NaN
% 		6   12.9    800      8      2    225    246    239
% 		...
%
% -------------------------------------------------------------------------
%
% EXAMPLE 3b:
%
% »
% 1 yellow 1 0 0
% 2 green  7 8 7
% 3 red    0 0 0
% 4 green  8 8 9
% 5 green  9 7 7
% 6 yellow 0 2 1
% «
% If you want to get the numeric data only from the lines containing the string
% 'green':
%
% t2mOpts = {'NumHeaderLines', 0                , ...
%            'NumColumns'    , 4                , ...
%            'ConvString'    , '%f %*s %f %f %f', ...
%            'GoodLineString', {'green'}           };
%        
% A = txt2mat_test('C:\mydata.log', t2mOpts{:});
%
%   A =
%       2     7     8     7
%       4     8     8     9
%       5     9     7     7
%
% -------------------------------------------------------------------------
%
% EXAMPLE 4:
%
% Supposed your ascii file C:\mydata.log begins with the following lines:
% »
% datetime	%	ppm	%	ppm	Nm
% datetime	real8	real8	real8	
% 30.10.2006 14:24:06,131	6,4459	478,519	6,5343	
% 30.10.2006 14:24:17,400	6,4093	484,959	6,5343	
% 30.10.2006 14:24:17,499	6,4093	484,959	6,5343	
% «
% you might specify 
% nh   = 2          % header lines, 
% nc   = 9          % data columns,
% cstr = ['%d.%d.%d' repmat('%f',1,6)] % as conversion string for
%                                      % integers and hexadecimals,  
% sr1  = ': '       % as first replacement string to blank the ':'
% sr2  = ',.'       % to replace the decimal comma with a dot, and
%
% A = txt2mat('C:\mydata.log', nh, nc, cstr, {sr1,sr2});
%
%   A =
% 		30  10  2006  14  24   6.131  6.4459  478.519  6.5343
% 		30  10  2006  14  24  17.4    6.4093  484.959  6.5343
% 		30  10  2006  14  24  17.499  6.4093  484.959  6.5343
%       ...
% 
% 
% A = txt2mat('C:\mydata.log','ReplaceRegExpr',{{'\.(\d+)\.',' $1 '}});
%
% yields the same result, but uses the built-in file layout analysis to
% determine the number of header lines, the number of columns, the
% delimiters, and the decimal character. You only help TXT2MAT by
% telling it to replace dots surrounding the month number with spaces via
% the regular expression replacement. So you can use the latter command on
% similar files which have a different or previously unknown number of
% header lines etc., too. 
%
% -------------------------------------------------------------------------
%
% EXAMPLE 5:
%
% If the data table of your file contains some gaps that can be identified
% by some repeated delimiters (here ;)
% »
% ; 02; 03; 04; 05;
% 11; ; 13; 14; 15;
% 21; ; 23; ;;
% ; 32; 33; 34; 35;
% «
% you can fill them with NaNs by the help of 'ReplaceRegExpr':
%
% A = txt2mat('C:\mydata.log','ReplaceRegExpr',...
%                       {{'((?<=;\s*);)|(^\s*;)','NaN;'}});
%
%   A =
%        NaN     2     3     4     5
%         11   NaN    13    14    15
%         21   NaN    23   NaN   NaN
%        NaN    32    33    34    35
%    
%    
% -------------------------------------------------------------------------
%
% EXAMPLE 6:
% 
% If you want to process the contents of mydata.log step by step,
% converting one million lines at a time:
%
% fp  = 0;          % File position to start with (beginning of file)
% A   = NaN;        % initialize output matrix
% nhl = 12;         % number of header lines for the first call
% 
% while numel(A)>0
%     [A,ffn,nh,SR,hl,fp] = txt2mat('C:\mydata.log','RowRange',[1,1e6], ...
%                                   'FilePos',fp,'NumHeaderLines',nhl);
%     nhl = 0;      % there are no further header lines
%
%     % process intermediate results...
% end
% 
% -------------------------------------------------------------------------
%
% EXAMPLE 7:
% 
% You can use the read mode 'block' on very large files with a constant
% number of values per line to save some import time compared to the
% 'matrix' mode. Besides, as TXT2MAT does not check for line breaks within
% the (internally processed) sections of a file, you can use the block mode
% to fill up any output matrix with a fixed number of columns.
% »
%  1  2  3  4  5
%  6  7  8  9 10
%    
% 11 12 13 14 15
% 16 17 18 19 20
% 21 22
% 23 24 25
% 26 27 28 29 30
%
% «
% 
% A = txt2mat('C:\mydata.txt',0,5,'ReadMode','block')
% 
% A =
%      1     2     3     4     5
%      6     7     8     9    10
%     11    12    13    14    15
%     16    17    18    19    20
%     21    22    23    24    25
%     26    27    28    29    30
%
%
% Instead, if you want to preserve the line break information, use read
% mode 'line': 
%
% A = txt2mat('C:\mydata.txt',0,5,'ReadMode','line')
%
% or
%
% A = txt2mat('C:\mydata.txt',0,-1)
%
% A =
%      1     2     3     4     5
%      6     7     8     9    10
%    NaN   NaN   NaN   NaN   NaN
%     11    12    13    14    15
%     16    17    18    19    20
%     21    22   NaN   NaN   NaN
%     23    24    25   NaN   NaN
%     26    27    28    29    30
%
% The first command reads up to 5 elements per line, starting from the
% first, and puts them to a Nx5 matrix, whereas the second one
% automatically expands the column size of the output to fit in the maximum
% number of elements occuring in a line. This is effected by the negative
% column number argument that also implies read mode 'line' here.
%  
% -------------------------------------------------------------------------
%
%   See also SSCANF


% --- Author: -------------------------------------------------------------
%   Copyright 2005-2008 A.Tönnesmann
%   $Revision: 6.04 $  $Date: 2008/12/02 09:12:02 $
% --- E-Mail: -------------------------------------------------------------
% x=-2:3;
% disp(char(round([-0.32*x.^5+0.43*x.^4+1.75*x.^3-5.90*x.^2-0.95*x+116,...
%                  -4.44*x.^5+9.12*x.^4+29.8*x.^3-33.6*x.^2-52.9*x+ 98])))
% --- History -------------------------------------------------------------
% 05.61
%   · fixed bug: possible wrong headerlines output when using 'FilePos'
%   · fixed bug: produced an error if a bad line marker string was already
%     found in the first data line 
%   · corrected user information if sscanf fails in matrix mode
%   · added some more help lines
% 05.62
%   · allow negative NumColumns argument to capture a priori unknown
%     numbers of values per line
% 05.82 beta
%   · support regular expression replacements ('ReplaceRegExpr' argument)
%   · consider user supplied replacements when analysing the file layout
% 05.86 beta
%   · some code clean-up (argincheck subfunction, ...)
% 05.86.1
%   · fixed bug: possibly wrong numeric matlab version number detection
% 05.90
%   · consider skippable lines when analysing the file layout
%   · code rearrangements (subfun for line termination detection, ...)
% 05.96
%   · subfuns to find line breaks / bad-line pos and to initialize output A
%   · better handling of errors and 'degenerate' files, e.g. exit without
%     an error if the file selection dialogue was cancelled 
% 05.97
%   · fixed bug: error in file analysis if first line contains bad line
%     marker
%   · fixed bug: a bad line marker is ignored if the string is split up by
%     two consecutive internal sections
%   · better code readability in FindLineBreaks subfunction
% 05.97.1
%   · simplifications by skipping the header when reading from the file;
%     the header is now read separately and is not affected by any
%     replacements
%   · corrected handling of bad line markers that already appear in header
% 05.98
%   · corrected search for long bad line marker strings that could exceed
%     text dimensions
%   · speed-up by improved finding of line break positions
% 06.00
%   · introduction of 'high speed' read mode "block" requiring less line
%     break information
%   · 'MemPar' buffer value changed to scalar
%   · reduced memory demand by translating smaller text portions to char
%   · modified help
% 06.01
%   · fixed bug: possible error message in file analysis when only header
%     line number is given
% 06.04
%   · better handling of replacement strings containing line breaks
%   · allow '*' in file name to use file name as open file dialogue filter
% 06.12
%   · 'good line' filter as requested by Val Schmidt
% --- Wish list -----------------------------------------------------------

%% Definitions

% find out matlab version as a decimal, up to the second dot:
v = ver('matlab');
vs= v.Version;
vsDotPos = [strfind(vs,'.'), Inf, Inf];
vn= str2double(vs(1:min(numel(vs),vsDotPos(2)-1)));

%% Get input arguments

% check the arguments in the (still amendable) subfunction 'argincheck':
ia = argincheck(varargin);

if ~isempty(ia.errmsg)
    error(ia.errmsg)
end

% unwrap input argument information
is_argin_num_header	= ia.is_argin_num_header;
num_header         	= ia.num_header;
is_argin_num_colon 	= ia.is_argin_num_colon;
num_colon          	= ia.num_colon;
conv_str          	= ia.conv_str;
sr_input_ca        	= ia.sr_input_ca;
num_sr             	= ia.num_sr;
kl_input_ca         = ia.kl_input_ca;
num_kl              = ia.num_kl;
replace_expr        = ia.replace_expr;
num_er              = ia.num_er;
idx_rng             = ia.idx_rng;
% ldx_rng             = ia.ldx_rng;     % has become obsolete since v6.00
infolvl             = ia.infolvl;
is_argin_readmode   = ia.is_argin_readmode;
readmode            = ia.readmode;
numerictype         = ia.numerictype;
is_argin_rowrange   = ia.is_argin_rowrange;
rowrange            = ia.rowrange;
filepos             = ia.filepos;
is_argin_filepos    = ia.is_argin_filepos;
replace_regex       = ia.replace_regex;
num_rr              = ia.num_rr;
ffn                 = ia.ffn;
ffn_short           = ia.ffn_short;
num_gl              = ia.num_gl;
gl_input_ca         = ia.gl_input_ca;

if exist(ffn,'file')~=2 % check again (e.g. after ESC in open file dialogue)
    [A,ffn,num_header,sr_input_ca,hl,fpos] = deal([]);
    if infolvl>=1
        disp('Exiting txt2mat: No existing file given.')
    end
    return
end

clear varargin ia

%% Analyse data format

% try some automatic data format analysis if needed (by function anatxt)
doAnalyzeFile = ~all([is_argin_num_header, is_argin_num_colon]); %, is_argin_conv_str]); % commented out as so far anatxt's conv_str is only '%f'

if doAnalyzeFile 
    % call subfunction anatxt:
    [ffn, ana_num_header, ana_num_colon, ana_conv_str, ana_sr_input_ca,...
        ana_rm, num_ali, ana_hl, ferrmsg, aerrmsg] = anatxt(ffn,filepos,sr_input_ca,replace_expr,replace_regex,kl_input_ca,num_header,vn);
    % quit if errors occurred
    if ~isempty(aerrmsg)
        [A,sr_input_ca,fpos] = deal([]);
        num_header = ana_num_header;
        hl = ana_hl;
        if infolvl>=1
            disp(['Exiting txt2mat: file analysis: ' aerrmsg])
        end
        return
    end
        
    % accept required results from anatxt:
    if ~is_argin_num_header
        num_header = ana_num_header;
    end
    if ~is_argin_num_colon
        num_colon = ana_num_colon;
    end
    %if ~is_argin_conv_str      
    %    conv_str = ana_conv_str;
    %end
    if ~is_argin_readmode
        readmode = ana_rm;
    end
    % add new replacement strings from anatxt:
    is_new_sr   = ~ismember(ana_sr_input_ca, sr_input_ca);
    num_sr      = num_sr + sum(is_new_sr);
    sr_input_ca = [sr_input_ca,ana_sr_input_ca(is_new_sr)];
    % display information:
    if infolvl >= 1
        disp(repmat('*',1,length(ffn)+2));
        disp(['* ' ffn]);
        if numel(ferrmsg)==0
            sr_display_str = '';
            for idx = 1:num_sr;
                sr_display_str = [sr_display_str ' »' sr_input_ca{idx} '«']; %#ok<AGROW>
            end
            disp(['* read mode: ' readmode]);
            disp(['* ' num2str(num_ali)        ' data lines analysed' ]);
            disp(['* ' num2str(num_header)     ' header line(s)']);
            disp(['* ' num2str(abs(num_colon)) ' data column(s)']);
            disp(['* ' num2str(num_sr)         ' string replacement(s)' sr_display_str]);
        else
            disp(['* fread error: ' ferrmsg '.']);
        end
        disp(repmat('*',1,length(ffn)+2));
    end % if
    
    % return if anatxt did not detect valid data
    if ana_num_colon==0
        A = [];
        hl = '';
        fpos = filepos;
        return
    end
end

%% Detect line termination character

if infolvl >= 1
    hw = waitbar(0,'detect line termination character ...');
    set(hw,'Name',[mfilename ' - ' ffn_short]);
    hasWaitbar = true;
else
    hasWaitbar = false;
end

lbfull = detectLineBreakCharacters(ffn);
% DETECTLINEBREAKCHARACTERS find out type of line termination of a file
%
% lb = detectLineBreakCharacters(ffn)
%
% with
%   ffn     ascii file name
%   lb      line break character(s) as uint8, i.e.
%           [13 10]     (cr+lf) for standard DOS / Windows files
%           [10]        (lf) for Unix files
%           [13]        (cr) for Mac files
%
% The DOS style values are returned as defaults if no such line breaks are
% found.

lbuint = lbfull(end);      
lbchar = char(lbuint);
num_lbfull = numel(lbfull);     

%% Open file and set position indicator to end of header
% ... and extract header separately if not already done

logfid = fopen(ffn);
if num_header > 0
    if doAnalyzeFile % header lines have already been extracted
        hl = ana_hl;
        lenHeader = numel(hl);
        fseek(logfid,filepos+lenHeader,'bof');
    else
        if is_argin_filepos
            fseek(logfid,filepos,'bof');
        end
        
        read_len = 65536;   % (quite small) size of text sections just for header line extraction
        do_read  = true;
        num_lb_curr = 0;
        countLoop = 0;
        while do_read
            [f8p,lenf8p]    = fread(logfid,read_len,'*uint8');	% current text section

            ldcp_curr       = find(f8p==lbuint);                % line break positions in current text section
            num_lb_curr     = num_lb_curr + numel(ldcp_curr);   % number of line breaks so far
            
            do_read         = (lenf8p == read_len) && (num_lb_curr < num_header);
            countLoop       = countLoop + 1;
        end
        
        if num_lb_curr >= num_header
            lenHeader = ldcp_curr(end-(num_lb_curr-num_header)) + (countLoop-1)*read_len;
            if countLoop == 1
                % take the complete header from the first section
                hl = char(f8p(1:lenHeader)).';
                fseek(logfid,filepos+lenHeader,'bof');
            else
                % the header did not fit into a single section, so re-read
                % it as a whole
                fseek(logfid,filepos,'bof');
                hl = char(fread(logfid,lenHeader).');
            end
        else 
            % exit here as we have found less line breaks than the given
            % number of header lines!
            fseek(logfid,filepos,'bof');
            hl = char(fread(logfid).');
            fpos = ftell(logfid);
            fclose(logfid);
         	[A,sr_input_ca] = deal([]);
            if infolvl>=1
                disp(['Exiting txt2mat: '  num2str(num_header) ' header lines expected, but only ' num2str(num_lb_curr) ' line breaks found.'])
                close(hw)
            end
          	return
            
        end
    end
else
    lenHeader = 0;
    hl = '';
    if is_argin_filepos
     	fseek(logfid,filepos,'bof');
    end
end

%% Read in ASCII file - case 1: portions only, as RowRange is given.
% RowRange should be given if the file is too huge to be read at once by
% fread. In this case multiple freads are used to read in consecutive
% sections of the text. By counting the line breaks those rows of the text
% that match the RowRange argument are added to the 'core' variable f8 that
% is later used for the numeric conversion.

% By definition, a line begins with its first character and ends with its
% last termination character.

if hasWaitbar
    waitbar(0.01,hw,'reading file ...');
end

% numHeader = 0; % auxilliary variable replacing "num_header" during the code reconstruction

if is_argin_rowrange
    do_read             = true;     % loop condition
    num_lb_prev         = 0;
    read_len            = idx_rng;
    f8                  = [];
    while do_read
        [f8p,lenf8p]  = fread(logfid,read_len,'*uint8');  	% current text section

        ldcp_curr       = find(f8p==lbuint);                % line break positions in current text section
        num_lb_curr     = numel(ldcp_curr);

        % add lines of interest to f8
        if (rowrange(1) <= num_lb_prev+num_lb_curr+1) && (num_lb_prev < rowrange(2))

            if rowrange(1) <= num_lb_prev + 1	% lines of interest started before current section
                sdx = 1;                                        % start index is beginning of section => the part of the section to be added to f8 includes the start of the section 
            else                                                % lines of interest start within current section
                num_lines_to_omit = rowrange(1)-1-num_lb_prev;  % how many lines not to add
                sdx = ldcp_curr(num_lines_to_omit)+1;         	% start right after the omitted lines
            end

            if rowrange(2) > num_lb_curr+num_lb_prev    % lines of interest end beyond current section
                edx = lenf8p;                                   % end index is length of section => the part of the section to be added to f8 includes the end of the section 
            else                                                % lines of interest end within current section
                num_lines_to_add = rowrange(2)-num_lb_prev;     % how many lines to add
                edx = ldcp_curr(num_lines_to_add);             	% corresponding end index
            end

            f8 = [f8; f8p(sdx:edx)]; %#ok<AGROW>
            fpos = ftell(logfid)-lenf8p+edx;       % position of the latest added character 
        end

        % quit loop if all rows of interest are read or if end of file is reached 
        if num_lb_prev >= rowrange(2) || lenf8p<read_len
            do_read = false;
        end
        num_lb_prev          = num_lb_prev + num_lb_curr;  	% absolute number of dectected line breaks
    end
    
end
%% Read in ASCII file - case 2: full file. Then close file.

if ~is_argin_rowrange
    [f8,fcount]  = fread(logfid,Inf,'*uint8');
    fpos = fcount + filepos + lenHeader;
end

if ftell(logfid) == -1
    error(ferror(fid, 'clear'));
end

fclose(logfid); 

if numel(f8)==0
    A = [];
    if infolvl>=1
        disp('Exiting txt2mat: no numeric data found.')
        close(hw)
    end
    return
end


%% Clean up whitespaces at the end of file

f8 = cleanUpFinalWhitespace(f8,lbfull);


%% Find linebreak indices and good and bad line positions

% as finding the line breaks is time-critical, "LbAwareness" is
% introduced to tell us what we know about line break positions:
% 0: nothing
% 1: the positions of the final line break in every section
% 2: the above + the number of lines up to each of those line breaks
% 3: all line break positions

% determine the minimum LbAwareness required for the numeric conversion:
switch lower(readmode)
    case 'block'
        MinLbAwareness = 1;
    case {'matrix','auto'}
        MinLbAwareness = 2;
    case 'line'
        MinLbAwareness = 3;
end

kl_idc = [];    % default (no indices of rows to be deleted)
gl_idc = [];    % default (no indices of rows to be deleted)
if num_kl + num_gl > 0
    if hasWaitbar
        waitbar(0.10,hw,'finding line breaks ...');
    end
    
    [lf_idc, cntLb, secLbIdc, kl_idc, gl_idc] = FindLineBreaks(f8, lbuint, ...
           idx_rng, true, false, num_kl, kl_input_ca, num_gl, gl_input_ca);

    LbAwareness = 3;
else
    LbAwareness = 0;
end


%% Filter good/bad lines

hasGoodLineMarkers = false;
hasBadLineMarkers  = false;
if num_gl > 0   % good line markers were to be found
    if isempty(gl_idc)
        A = [];
        if infolvl>=1
            disp('Exiting txt2mat: no ''good line'' strings found.')
            close(hw)
        end
        return
    else
        if hasWaitbar
            waitbar(0.15,hw,'deleting rows ...');
        end
        
        % find indices of line breaks bordering a marker
        [goodL,goodR] = neighbours(gl_idc, lf_idc);
        
        % care for multiple markers within a single row
        if any(diff(goodL) <= 0) && any(diff(goodR) <= 0)
            goodL = unique(goodL);
            goodR = unique(goodR);
        end
        
        % combine consecutive line sections
        isCommon = goodL(2:end) == goodR(1:end-1);
        if any(isCommon)
            goodL([false;isCommon]) = [];
            goodR([isCommon;false]) = [];
        end

    end
    hasGoodLineMarkers = true;
    doKeep             = true;
end

if ~isempty(kl_idc)
    if hasWaitbar
        waitbar(0.15,hw,'deleting rows ...');
    end

    % find indices of line breaks bordering a marker
	[badL,badR] = neighbours(kl_idc, lf_idc);
    
    % care for multiple markers within a single row
    if any(diff(badL) <= 0) && any(diff(badR) <= 0)
        badL = unique(badL);
        badR = unique(badR);
    end
    
    % combine consecutive line sections
    isCommon = badL(2:end) == badR(1:end-1);
    if any(isCommon)
        badL([false;isCommon]) = [];
        badR([isCommon;false]) = [];
    end
    
    hasBadLineMarkers = true;
    doKeep            = false;
end

if hasGoodLineMarkers && hasBadLineMarkers
    iGood = endpoint2logical(numel(f8),goodL+1,goodR,true );
    iBad  = endpoint2logical(numel(f8), badL+1, badR,false);
    f8 = f8(iGood & iBad);
    LbAwareness = 0;
elseif hasGoodLineMarkers
    f8 = cutvec(f8,goodL+1,goodR,doKeep,vn);
    LbAwareness = 0;
elseif hasBadLineMarkers
    f8 = cutvec(f8,badL+1,badR,doKeep,vn);
    LbAwareness = 0;
end
    
clear L R kl_idc iGood goodL goodR iBad badL badR

%% Find line break positions

if LbAwareness == 0
    
    if hasWaitbar
        waitbar(0.20,hw,'updating line break positions ...');
    end
    
    % Find out if we have to expect text length changes due to the
    % replacemets
    doExpectLengthChange = false;   % default
    if num_rr > 0
        % always expect changes by regular expressions
        doExpectLengthChange = true;
    else
        % check for string replacements that will change the length
        for edx = 1:num_er
            if any(diff(cellfun('length', replace_expr{edx})))
                doExpectLengthChange = true;
                break
            end
        end
    end
    
    if doExpectLengthChange || strcmpi(readmode,'block')
        % - make K1
        doFindAll = false;
        doCount   = false;
        LbAwareness = 1;
    else
        if strcmpi(readmode,'line')
        	% - make K3
            doFindAll = true;
            doCount   = true;
            LbAwareness = 3;
        else  % readmode is 'auto' or 'matrix'
            % - make K2
            doFindAll = false;
            doCount   = true;
            LbAwareness = 2;
        end
    end

    [lf_idc,cntLb,secLbIdc] = FindLineBreaks(f8, lbuint, idx_rng, doFindAll, doCount, 0, {}, 0, {});
end

%% Replace (regular) expressions and characters

%f8=char(f8);                % quicker with strrep, required by sscanf 
doReplaceLb = false;   % default, to be checked below

if num_rr > 0
    has_length_changed = true;
else
    has_length_changed = false; % flag for changes of length of f8 by replacements
end

if any([num_sr,num_er,num_rr] > 0 )
    if hasWaitbar
        waitbar(0.20,hw,'replacing strings ...');
    end

    numSectionLb = numel(secLbIdc);

    % If a ReplaceExpr begins with a line break character, such a character
    % will temporarily be prepended to each replacement section to apply
    % the replacement to the _first_ line of a section, too.
    % Besides, check for any occurence of the break character in the
    % ReplaceExpr in order to preventively trigger an update of the line
    % break positions afterwards.
    % Set defaults before checking:
    doPrependLb = false;   
    numPrepend  = 0;       
    if num_er>0
        % put all the characters from the ReplaceExpr strings into an
        % uint8-array:
        uint8Replace = uint8(char([replace_expr{:}]));
        % check if any row starts with a line break:
        if any(uint8Replace(:,1)==lbuint)
            doPrependLb = true;
            numPrepend  = 1;
        end
        if any(uint8Replace(:)==lbuint)
            doReplaceLb = true;
        end
    end
    
    for sdx = 2:numSectionLb
        
        if doPrependLb
            f8_akt = char([lbuint, f8(lf_idc(secLbIdc(sdx-1))+1 : lf_idc(secLbIdc(sdx))).']);
        else
            f8_akt = char(f8(lf_idc(secLbIdc(sdx-1))+1 : lf_idc(secLbIdc(sdx))).');
        end
        
        if num_er > 0 || num_rr > 0
            len_f8_akt = lf_idc(secLbIdc(sdx)) - lf_idc(secLbIdc(sdx-1));  % length of current section before replacements

            % Replacements, e.g. {'odd','one','1'} replaces 'odd' and 'one' by '1'

            % Regular Expression Replacements: ============================
            for vdx = 1:num_rr                  % step through replacements arguments
                srarg = replace_regex{vdx};    	% pick a single argument...

                for xdx = 1:(numel(srarg)-1)
                    f8_akt = regexprep(f8_akt, srarg{xdx}, srarg{end});     % ... and perform replacements
                end % for

            end % for

            % Expression Replacements: ====================================
            for vdx = 1:num_er                  % step through replacements arguments
                srarg = replace_expr{vdx};    	% pick a single argument...

                for xdx = 1:(numel(srarg)-1)
                    f8_akt = strrep(f8_akt, srarg{xdx}, srarg{end});        % ... and perform replacements
                    if ~has_length_changed && (len_f8_akt~=numel(f8_akt))
                        has_length_changed = true;                          % detect a change of length of f8
                    end
                end % for

            end % for

            % update f8-sections by f8_akt ================================
            exten = numel(f8_akt) - len_f8_akt;	% extension by replacements
            
            if exten == 0   
                if doPrependLb
                    f8( lf_idc(secLbIdc(sdx-1))+1 : lf_idc(secLbIdc(sdx)) ) = uint8(f8_akt(1+numPrepend:end)).';
                else
                    f8( lf_idc(secLbIdc(sdx-1))+1 : lf_idc(secLbIdc(sdx)) ) = uint8(f8_akt).';
                end
            else   
                if doPrependLb
                    f8 = [f8(1:lf_idc(secLbIdc(sdx-1))); uint8(f8_akt(1+numPrepend:end)).'; f8(lf_idc(secLbIdc(sdx))+1:end)];
                else
                    f8 = [f8(1:lf_idc(secLbIdc(sdx-1))); uint8(f8_akt).'                  ; f8(lf_idc(secLbIdc(sdx))+1:end)];
                end
                % update linebreak indices of the following sections
                % (but we don't know the lb indices of the current one anymore):
                lf_idc(secLbIdc(sdx:end)) = lf_idc(secLbIdc(sdx:end)) + exten;
            end
            
        end % if num_er > 0 || num_rr > 0
        
        % Character Replacements: =========================================
        for vdx = 1:num_sr                  % step through replacement arguments
            srarg = sr_input_ca{vdx};       % pick a single argument
            for xdx = 1:(numel(srarg)-1)
                rep_idx = lf_idc(secLbIdc(sdx-1))+strfind(f8_akt,srarg(xdx))-numPrepend;
                f8(rep_idx) = uint8(srarg(end));   % perform replacement
            end % for
        end
        
        if hasWaitbar && ~mod(sdx,256)
            waitbar(0.20+0.25*((sdx-1)/(numSectionLb-1)),hw)
        end
        
    end

    clear f8_akt
end % if


%% Update linebreak indices
% see above...

% if the final line break might have changed, clean up trailing whitespaces
% here again
if doReplaceLb || num_rr > 0
    f8 = cleanUpFinalWhitespace(f8,lbfull);
end

if has_length_changed || (LbAwareness < MinLbAwareness) || doReplaceLb
    if hasWaitbar
        waitbar(0.45,hw,'updating line break positions ...');
    end

    if strcmpi(readmode,'block')
        % - make K1
        doFindAll = false;
        doCount   = false;
        LbAwareness = 1;
    elseif strcmpi(readmode,'line')
        % - make K3
        doFindAll = true;
        doCount   = true;
        LbAwareness = 3;
    else  % readmode is 'auto' or 'matrix'
        % - make K2
        doFindAll = false;
        doCount   = true;
        LbAwareness = 2;
    end

    [lf_idc,cntLb,secLbIdc] = FindLineBreaks(f8, lbuint, idx_rng, doFindAll, doCount, 0, {}, 0, {});
end

% Determine the total number of line breaks (including the extra 'zero'
% line break and the eventually added final line break) depending on
% LbAwareness. If LbAwareness is less than 2, we can't know that number.
if LbAwareness == 2
    num_lf = cntLb(end)+1;
elseif LbAwareness == 3
    num_lf = numel(lf_idc);
else
    num_lf = NaN;
end

%% (ReadMode 'Block')

if strcmpi(readmode,'block')
    
    if hasWaitbar
        waitbar(0.5,hw,'converting in ''block'' mode ...');
    end
    
    numColonBlock   = abs(num_colon);   % number of columns in output matrix
    isNumelOk       = true;             % initialize flag "in every section the number of elements is a multiple of number of columns"
    numSectionLb    = numel(secLbIdc);  % 1 + number of sections to process
    doSetNan        = true;             % flag "output matrix will be initialized with NaNs"
    
    % convert first section ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    startIdcF8 = lf_idc(secLbIdc(1))+1;
    endIdcF8   = lf_idc(secLbIdc(2));
    
    % THE conversion of this section by sscanf:
    [Atmp,count,errmsg,nextindex] = ...
            sscanf(char(f8(startIdcF8 : endIdcF8)), conv_str);
    numAtmp = numel(Atmp);
	
    % examine how many elements we found in this section
    numRowsCurr      = ceil(numAtmp/numColonBlock);         % how many rows will contain these elements
    numelMissing     = numRowsCurr*numColonBlock-numAtmp;   % how many elements are missing to fill up the last of these rows

    a = InitializeMatrix(1,1,numerictype,doSetNan,vn);
    
    if numSectionLb < 3
        % there is only one section, so just generate the final output
        % matrix here:
        A = reshape([Atmp;repmat(a,numelMissing,1)],numColonBlock,numRowsCurr).';
        if numelMissing>0
            isNumelOk = false;
        end
    else
        % there are multiple sections, so initialize the output matrix
        % first ...
        if isnan(num_lf)
              % guess final size of A for preallocating
              expandFactor   = diff(lf_idc(secLbIdc([1,end])))/diff(lf_idc(secLbIdc([1,2])));
              numRowsGuessed = round(numRowsCurr * expandFactor);
        else
            numRowsGuessed = num_lf;
        end
        A = InitializeMatrix(numRowsGuessed,numColonBlock,numerictype,doSetNan,vn);

        % ... and put the first elements to it:
        startRow = 1;
        endRow   = numRowsCurr;
        Atmp = reshape([Atmp;repmat(a,numelMissing,1)],numColonBlock,numRowsCurr).';
        A(startRow:endRow,1:numColonBlock) = Atmp;

        % If the first section was incomplete, the first elements of the
        % second section will be added to the last row of the first
        % section. So keep in mind the elements of the incomplete row here:
        if numelMissing>0
            isNumelOk = false;
            repeatRow = 1;
            ARepeat = A(endRow,1:(numColonBlock-numelMissing)).';
        else
            repeatRow = 0;
            ARepeat = [];
        end

        % now step through the following sections
        for sdx = 2:numSectionLb-1

            % the text positions of the current section:
            startIdcF8 = lf_idc(secLbIdc(sdx))+1;
            endIdcF8   = lf_idc(secLbIdc(sdx+1));

            % THE conversion of this section by sscanf:
            [Atmp,count,errmsg,nextindex] = ...
                sscanf(char(f8(startIdcF8 : endIdcF8)), conv_str);
            numAtmp = numel(Atmp);
            if numAtmp == 0
                Atmp = double(Atmp);
            end

            % as with the first section, add the new values the output
            % matrrix
            numRowsCurr  = ceil( (numAtmp-numelMissing) / numColonBlock );
            numelMissing = numRowsCurr*numColonBlock-(numAtmp-numelMissing);
            startRow     = endRow+1-repeatRow;
            endRow       = endRow+numRowsCurr;
            
            Atmp = reshape([ARepeat;Atmp;repmat(a,numelMissing,1)],numColonBlock,numRowsCurr+repeatRow).';
            A(startRow:endRow,1:numColonBlock) = Atmp;     
            
            % remember elements of an incomplete row for the next section
            if numelMissing>0
                isNumelOk = false;
                repeatRow = 1;
                ARepeat = A(endRow,1:(numColonBlock-numelMissing)).';
            else
                repeatRow = 0;
                ARepeat = [];
            end
            
            if hasWaitbar && ~mod(sdx,256)
                waitbar(0.5+0.5*((sdx-1)/(numSectionLb-1)),hw)
            end
            
        end
        
        if numRowsGuessed > endRow
            A = A(1:endRow,:);
            % A(endRow+1:numRowsGuessed,:) = [];
        end
        
    end
    
    if ~isNumelOk
        warning('txt2mat:NumberOfElements', 'Number of elements did not fill up a complete row')
    end
        
end

%% Try converting large sections (ReadMode 'Matrix')
% sscanf will be applied to consecutive working sections consisting of
% <ldx_rng> rows. The number of numeric values must then be a multiple of
% the number of columns. Otherwise, or if sscanf produces an error, inform
% the user and eventually proceed to the (slower) line-by-line conversion.


errmsg = '';    % Init. error message variable
if strcmpi(readmode,'auto') || strcmpi(readmode,'matrix') 
    if hasWaitbar
        waitbar(0.5,hw,'converting in ''matrix'' mode ...');
    end
    
    try
        numColonMatrix  = abs(num_colon);
        errorType = 'none';         % 
        A = InitializeMatrix(num_lf-1,numColonMatrix,numerictype,false,vn);
        
        % Usually, in 'matrix' mode, we have LbAwareness == 2. As the way
        % we calculate the number of rows in a section depends on
        % LbAwareness, we check that here: 
        hasNotAllLb = LbAwareness < 3;
        
        numSectionLb = numel(secLbIdc);
        
        %*% for testing purposes: aggregate multiple sections to a larger one 
        %sectionStep =1;    % how many sections to aggregate
        %selectedSectionIdc = min(2:sectionStep:numSectionLb+sectionStep-1, numSectionLb);
        %*% in this case, use max(1,sdx-sectionStep) instead of sdx-1 below 
        
        selectedSectionIdc = 2:numSectionLb;
    
        for sdx = selectedSectionIdc
            
            % start and end indices of the current section in the text:
            startIdcF8 = lf_idc(secLbIdc(sdx-1))+1;
            endIdcF8   = lf_idc(secLbIdc(sdx));
            
            % THE conversion of this section by sscanf:
            [Atmp,count,errmsg,nextindex] = ...
                    sscanf(char(f8(startIdcF8 : endIdcF8)), conv_str); 

            % the correponding row indices of the output matrix:
            if hasNotAllLb
                startRow       = cntLb(sdx-1)+1;
                endRow         = cntLb(sdx);
            else
                startRow       = secLbIdc(sdx-1);
                endRow         = secLbIdc(sdx)-1;
            end
            num_lines_loop = endRow - startRow + 1;
            
            %~% error handling ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            if ~isempty(errmsg) 
                % there's an sscanf error message
                errorType = 'sscanf';
                break
            elseif numel(Atmp) ~= numColonMatrix * num_lines_loop
                % we did not read the expected number of numeric elements
                errorType = 'numel';
                numelExpected = numColonMatrix * num_lines_loop;
                numelFound    = numel(Atmp);
                break
            end
            %~% end error handling ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            
            % put the values to the right dimensions and add them to A
            Atmp = reshape(Atmp,numColonMatrix,num_lines_loop)';
            A(startRow:endRow,:) = Atmp;
            
            if hasWaitbar && ~mod(sdx,256)
                waitbar(0.5+0.5*((sdx-1)/(numSectionLb-1)),hw)
            end

        end % for sdx = 2:numSectionLb
        
        % error diagnosis and user information ~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        switch errorType
            case 'sscanf'
                if (infolvl >= 2) && ( nextindex <= endIdcF8 - startIdcF8 + 1 )  
                    % If sscanf did not process the whole string, display
                    % the text line where it stopped.
                    
                    % line break indices in the current section
                    idcLbCurr = [0, strfind(f8(startIdcF8 : endIdcF8).', lbchar)];
                    % find line break index of the abortion line
                    idxErrorLine = min(find(idcLbCurr-nextindex > 0));    %#ok<MXFND> 
                    % text content of the abortion line
                    errorLineText = f8(startIdcF8 + (idcLbCurr(idxErrorLine-1):idcLbCurr(idxErrorLine)-num_lbfull-1) ).';
                    % display information about the error cause
                    disp(['Sscanf error after reading ' num2str((startRow-1)*numColonMatrix+count) ' numeric values.'])
                    disp(['Text content of the critical row (no. ' num2str(num_header+startRow-1+idxErrorLine-1) ' without deleted lines): '])
                    disp(errorLineText)
                end % if
                
            case 'numel'
                if infolvl >= 2
                    % We don't know the exact lines containing the wrong
                    % number of values. As a guess, just display the
                    % positions of the longest or the shortest text lines
                    % (by simply counting characters).
                    
                    % line break indices in the current section
                    idcLbCurr = [0, strfind(f8(startIdcF8 : endIdcF8).', lbchar)];
                    % corresponding text line lengths
                    lenLine = diff(idcLbCurr);
                    [lenLineSorted,idclenLineSorted] = sort(lenLine);
                    maxNumDisplayed = min(5,numel(lenLine));

                    if numelFound < numelExpected
                        disp(['Found less elements (' num2str(numelFound) ') than expected (' num2str(numelExpected) ') in the current section.'])
                        disp('As a hint, these are the text lines containing the least characters:')
                        disp(['lines no. [' num2str(num_header+startRow-1+idclenLineSorted(1:maxNumDisplayed)) '] having [' num2str(lenLineSorted(1:maxNumDisplayed),' %i') '] characters, resp.'])
                    else
                        disp(['Found more elements (' num2str(numelFound) ') than expected (' num2str(numelExpected) ') in the current section.'])
                        disp('As a hint, these are the text lines containing the most characters:')
                        disp(['lines no. [' num2str(num_header+startRow-1+idclenLineSorted(end:-1:end-maxNumDisplayed+1)) '] having [' num2str(lenLineSorted(end:-1:end-maxNumDisplayed+1),' %i') '] characters, resp.'])
                    end
                end
                error('Unexpected number of elements in read mode ''matrix''.')
        end
        % end error diagnosis and user information ~~~~~~~~~~~~~~~~~~~~~~~~        
        
    catch   %#ok<CTCH> % catch further errors (old catch style)
        if ~exist('errmsg','var') || isempty(errmsg)
            errmsg = lasterr; %#ok<LERR> (old catch style)
        end
    end % try
end

% Quit on error if 'matrix'-mode was enforced: 
if strcmpi(readmode,'matrix') && ~isempty(errmsg)
    if infolvl >= 1
        close(hw)
    end
    error(errmsg);
end


%% Converting line-by-line (ReadMode 'Line')

clear Atmp

if strcmpi(readmode,'line') || ~isempty(errmsg) 
    num_data_per_row = zeros(num_lf-1,1);
    
    if ~strcmpi(readmode,'line')
        num_colon = -abs(num_colon);
        if infolvl >= 2
            disp('Due to error')
            disp(strrep(['  ' errmsg],char(10),char([10 32 32])))
            disp('txt2mat will now try to read line by line...')
        end % if
    end
    
    if LbAwareness < 3
        lf_idc = FindLineBreaks(f8, lbuint, idx_rng, true, false, 0, {}, 0, {});
        num_lf = numel(lf_idc);
    end

    % initialize result matrix A depending on matlab version:
    width_A = max(abs(num_colon),1);
    [A,A1] = InitializeMatrix(num_lf-1,width_A,numerictype,true,vn);

    if hasWaitbar
        if strcmpi(readmode,'line')
            waitbar(0.5,hw,{'reading line-by-line ...'})
        else
            poshw = get(hw,'Position');
            set(hw,'Position',[poshw(1), poshw(2)-4/7*poshw(4), poshw(3), 11/7*poshw(4)]);
            waitbar(0.5,hw,{'now reading line-by-line because of error:';['[' errmsg ']']})
            set(findall(hw,'Type','text'),'interpreter','none');
        end
        drawnow
    end
	
	% extract numeric values line-by-line:
	for ldx = 1:(num_lf-1)
        a = sscanf(char(f8( (lf_idc(ldx)+1) : lf_idc(ldx+1)-1 )),conv_str)';
        num_data_per_row(ldx) = numel(a);
        % If necessary, expand A along second dimension (allowed if
        % num_colon < 0)
        if (num_data_per_row(ldx) > width_A) && (num_colon < 0)
            A = [A, repmat(A1,size(A,1),...
                 num_data_per_row(ldx)-width_A)]; %#ok<AGROW>
            width_A = num_data_per_row(ldx);
        end
        A(ldx,1:min(num_data_per_row(ldx),width_A)) = a(1:min(num_data_per_row(ldx),width_A));
        
        % display waitbar:
        if hasWaitbar && ~mod(ldx,10000)
                waitbar(0.5+0.5*(ldx./(num_lf-1)),hw)
        end % if
	end % for
    
    % display info about number of numeric values per line
    if infolvl >= 2
        if num_colon>=0
            reference = num_colon;
        elseif num_colon == -1;
            reference = width_A;
        else
            reference = -num_colon;
        end
        
        disp('Row length info:')
        idc_less_data = find(num_data_per_row<reference);
        idc_more_data = find(num_data_per_row>reference);
        num_less_data = numel(idc_less_data);
        num_more_data = numel(idc_more_data);
        num_equal_data = num_lf-1 - num_less_data - num_more_data;
        info_ca(1:3,1) = {['  ' num2str(num_equal_data)];['  ' num2str(num_less_data)];['  ' num2str(num_more_data)]};
        info_ca(1:3,2) = {[' row(s) found with ' num2str(reference) ' values'],...
                           ' row(s) found with less values',...
                           ' row(s) found with more values'};
        info_ca(1:3,3) = {' ';' ';' '};
        if num_less_data>0
            info_ca{2,3} = [' (row no. ', num2str(num_header+idc_less_data(1:min(10,num_less_data))'), repmat(' ...',1,num_less_data>10), ')'];
        end
        if num_more_data>0
            info_ca{3,3} = [' (row no. ', num2str(num_header+idc_more_data(1:min(10,num_more_data))'), repmat(' ...',1,num_more_data>10), ')'];
        end
        disp(strcatcell(info_ca));

    end % if infolvl >= 2
    
end % if

if infolvl >= 1
    close(hw)
end


%% : : : : : subfunction ANATXT : : : : : 

function [ffn, nhOrig, nc, cstr, SR, RM, llta, hl, ferrmsg, aerrmsg] = anatxt(ffn,fpos,sr_input_ca,replace_expr,replace_regex,kl_input,nh,vn)

% ANATXT analyse data layout in a text file for txt2mat
% 
% Usage:
% [ffn, nh, nc, cstr, SR, RM, llta, hl, ferrmsg] = ...
%       anatxt(fn,fpos,sr_input_ca,replace_expr,replace_regex,nh);
%
% ffn           full file name of analysed file
% nh            number of header lines
% nc            number of columns
% cstr          conversion string (curr. always '%f')
% SR            character replacement string
% RM            recommended read mode
% llta          lines analysed after header
% hl            header line characters
% ferrmsg       file operation error message
% aerrmsg       other error messages from this function
%
% fn            file name
% fpos          file position to start reading at
% sr_input      character replacement argument as for txt2mat
% replace_expr  expression replacement argument as for txt2mat
% replace_regex regular expression replacement argument as for txt2mat
% kl_input      cell array of strings to skip lines
% nh            number of header lines; NaN if not provided
% vn            matlab version number as a scalar (e.g. 6.5)
%   Copyright 2006 A.Tönnesmann,
%   $Revision: 2.86 $  $Date: 2008/10/25 13:05:08 $

num_rr       = length(replace_regex);
num_er       = length(replace_expr);
num_sr       = length(sr_input_ca);

[nc, llta] = deal(0);
[cstr, RM, hl, ferrmsg, aerrmsg] = deal('');
SR = {};
nhOrig = nh;
%% Read in file

% definitions
num_chars_read = 65536; % number of characters to read
has_nuff_n_ratio = 0.1; % this ratio will tell if a row has enough values
cstr     = '%f';        % assume floats only (so far)

has_ferror = false; % init
ferrmsg = '';       % init

logfid = fopen(ffn); 
if fpos > 0
    status = fseek(logfid,fpos,'bof');
    if status ~= 0
        has_ferror = true;
        ferrmsg = ferror(logfid,'clear');
    end
end

if ~has_ferror
    [f8,f8cnt] = fread(logfid,num_chars_read,'*uint8'); % THE read
    if f8cnt < num_chars_read
        did_read_to_end = true;
    else
        did_read_to_end = false;
    end
    f8 = f8';
end
fclose(logfid); 


if has_ferror
    aerrmsg = 'file operation error';
    return
end
if isempty(f8)
    aerrmsg = 'empty file';
    return
end

%% Find linebreaks

% Detect line termination character
lbfull = detectLineBreakCharacters(ffn);
lbuint = lbfull(end);        
lbchar = char(lbuint);

% if we are sure we read the whole file, add a final linebreak:
if did_read_to_end
    f8 = [f8,lbfull];
end

% preliminary linebreak positions:
idc_lb = find(f8==lbuint);

% position of the endmost printable ASCII character in f8
% (switch to uint8 and use V6.X find arguments for compatibility)
printasc = uint8([32:127, 128+32:255]);             % printable ASCIIs
idx_last_pa = max(find(ismembc(double(f8),double(printasc))));  %#ok<MXFND> % new syntax: find(ismembc(f8,dec_nr), 1, 'last' )

if isempty(idx_last_pa)
    aerrmsg = 'no printable characters found in file';
    return
end

% trim f8 after the first linebreak after this character, or, if none
% present, after the first linebreak before it:
if any(idc_lb>idx_last_pa)
    f8 = f8(1:min(idc_lb(idc_lb>idx_last_pa)));
else
    f8 = f8(1:max(idc_lb));
end
    
% recover linebreak positions
is_lb   = f8==lbuint;
idc_lb  = find(is_lb);

% remember the original text before deletions and replacements
f8Orig = char(f8);
idcLbOrig = idc_lb;

%% Find bad line positions

num_kl = numel(kl_input);
% Check for possible bad line markers
kl_idc = [];
if num_kl>0

    for idx = 1:num_kl                      % find positions of all markers
        kl_idx_akt = strfind(char(f8),kl_input{idx})';
        kl_idc = [kl_idc; kl_idx_akt]; %#ok<AGROW>
    end % for
end

%% Delete rows marked as bad if we found bad line markers

if ~isempty(kl_idc)

    % find indices of line breaks bordering a marker
    [L,R] = neighbours(kl_idc, [0,idc_lb]);
    % care for multiple markers within a single row
    if any(diff(L) <= 0) && any(diff(R) <= 0)
        L = unique(L);
        R = unique(R);
    end
    % delete the bad rows
    % f8 = cutvec(f8,L+1,R,false);
    [f8, idcLbNew] = cutvec(f8,L+1,R,false,vn,idcLbOrig);
    
    % update line break indices
    is_lb   = f8==lbuint;
    idc_lb  = find(is_lb);
end


%% Replace regular expressions, expressions and characters, if needed
        
if num_er>0 || num_sr>0 || num_rr>0
    
    % If a ReplaceExpr begins with a line break character, such a character
    % will temporarily be prepended to apply the replacement to the _first_
    % line, too.
    prependChar = '';       % prepend nothing by default
    if num_er>0
        % put all the characters from the ReplaceExpr strings into an
        % uint8-array:
        uint8Replace = uint8(char([replace_expr{:}]));
        % check if any row starts with a line break:
        if any(uint8Replace(:,1)==lbuint)
            prependChar = lbchar;
        end
    end
    numPrepend = numel(prependChar);
    
    f8=[prependChar, char(f8)];
    
    if num_rr>0
        for vdx = 1:num_rr                  % step through replacement arguments 
            srarg = replace_regex{vdx};    	% pick a single argument
            for sdx = 1:(numel(srarg)-1)
                f8 = regexprep(f8, srarg{sdx}, srarg{end});
            end
        end
    end

    if num_er>0
        for vdx = 1:num_er                  % step through replacement arguments 
            srarg = replace_expr{vdx};    	% pick a single argument
            for sdx = 1:(numel(srarg)-1)
                f8 = strrep(f8, srarg{sdx}, srarg{end});
            end
        end
    end

    if num_sr>0
        for vdx = 1:num_sr                  % step through replacement arguments
            srarg = sr_input_ca{vdx};       % pick a single argument
            for sdx = 1:(numel(srarg)-1)
                rep_idx = strfind(f8,srarg(sdx));
                f8(rep_idx) = srarg(end);   % perform replacement
            end
        end
    end
    
    f8 = uint8(f8(1+numPrepend:end));
    % update line break indices
    is_lb   = f8==lbuint;
    idc_lb  = find(is_lb);
end

num_lb  = numel(idc_lb);

f8c = char(f8);
f8d = double(f8);

%% Find character types

% types of characters:
dec_nr_p = sort(uint8('+-1234567890eE.NanIiFf'));   % decimals with NaN, Inf, signs and .
sep_wo_k = uint8([9 32    47 58 59]);   	% separators excluding comma  
sep_wi_k = uint8([9 32 44 47 58 59]);   	% separators including comma (Tab Space ,/:;)
komma    = uint8(',');               	% ,
other    = setdiff(printasc, [sep_wi_k, dec_nr_p]); % printables without separators and decimals

% characters not expected to appear in the data lines:
is_othr = ismembc(f8d,double(other));       % switch to double for compatibility 
is_beg_othr = diff([false, is_othr]);       % true where groups of such characters begin
idc_beg_othr = find(is_beg_othr==1);        % start indices of these groups
[S, sidx] = sort([idc_lb,idc_beg_othr]);    % in sidx, the numbers (1:num_lb) representing the linebreaks are placed between the indices of the start indices from above 
num_beg_othr_per_line = diff([0,find(sidx<=num_lb)]) - 1;   % number of character groups per line

% numbers enclosing a dot:
% idc_digdotdig = regexp(f8c, '[\+\-]?\d+\.\d+([eE][\+\-]?\d+)?', 'start');
idc_digdotdig = regexp(f8c, '[\+\-]?\d+\.\d+([eE][\+\-]?\d+)?');
[S, sidx] = sort([idc_lb,idc_digdotdig]);
num_beg_digdotdig_per_line = diff([0,find(sidx<=num_lb)]) - 1;

% numbers enclosing a comma:
% idc_digkomdig = regexp(f8c, '[\+\-]?\d+,\d+([eE][\+\-]?\d+)?', 'start');
idc_digkomdig = regexp(f8c, '[\+\-]?\d+,\d+([eE][\+\-]?\d+)?');
[S, sidx] = sort([idc_lb,idc_digkomdig]);
num_beg_digkomdig_per_line = diff([0,find(sidx<=num_lb)]) - 1;

% numbers without a dot or a comma:
% idc_numbers = regexp(f8c, '[\+\-]?\d+([eE][\+\-]?\d+)?', 'start');
idc_numbers = regexp(f8c, '[\+\-]?\d+([eE][\+\-]?\d+)?');
[S, sidx] = sort([idc_lb,idc_numbers]);
num_beg_numbers_per_line = diff([0,find(sidx<=num_lb)]) - 1;

% NaN and Inf items :
idc_nan = regexpi(f8c, '\<[\+\-]?(nan|inf)\>');
[S, sidx] = sort([idc_lb,idc_nan]);
num_beg_nan_per_line = diff([0,find(sidx<=num_lb)]) - 1;

% commas enclosed by numeric digits
% idc_kombd = regexp(f8c, '(?<=[\d]),(?=[\d])', 'start');
% if vn>=7
%     idc_kombd = regexp(f8c, '(?<=[\d]),(?=[\d])');  % lookaround new to v7.0??
% else
    idc_kombd = 1+regexp(f8c, '\d,\d');
% end
[S, sidx] = sort([idc_lb,idc_kombd]);
num_beg_kombd_per_line = diff([0,find(sidx<=num_lb)]) - 1;

% two sequential commas without a (different) separator inbetween
% idc_2kom  = regexp(f8c, ',[^\s:;],', 'start');
idc_2kom  = regexp(f8c, ',[^\s:;/],');

% commas:
is_kom  = f8==komma;
idc_kom = find(is_kom);
[S, sidx] = sort([idc_lb,idc_kom]);
num_kom_per_line = diff([0,find(sidx<=num_lb)]) - 1;


%% Analyse

if isnan(nh) % ~~~~~~~~~~~~ there's no user-supplied number of header lines
    % Determine number of header lines:
    nh = max([0, find(num_beg_othr_per_line>0)]); % for now, take the last line containing an 'other'-character 
    if nh>=num_lb
        aerrmsg = 'no numeric data found';
        if nh>0
            hl = char(f8(1:idc_lb(nh)));
        end
        return
    end
    num_beg_numbers_ph = num_beg_numbers_per_line(nh+1:end)+num_beg_nan_per_line(nh+1:end);    % number of lines following
    % by definition, a line is a valid data line if it contains enough
    % numbers compared to the average:
    has_enough_numbers = num_beg_numbers_ph>has_nuff_n_ratio.*mean(num_beg_numbers_ph);  
    nh = nh + min(find(has_enough_numbers)) - 1; %#ok<MXFND> 
    
    if nh>0    
        f8v_idx1 = idc_lb(nh)+1; % beginning of the data section in f8
        
        if ~isempty(kl_idc)
            % reconstruct header lines from the original text
            idcLbNewPos = find(cumsum(idcLbNew>0)==nh);
            nhOrig = idcLbNewPos(1); % number of header lines in the original text
        else
            nhOrig = nh;
        end
        hl = f8Orig(1:idcLbOrig(nhOrig));
    else
        f8v_idx1 = 1;
        hl = [];
        nhOrig = 0;
    end
else % ~~~~~~~~~~~~~~~ a number of header lines was given as input argument
    if nh>0
        hl = f8Orig(1:idcLbOrig(nh));
        if ~isempty(kl_idc)
            nh = sum(logical(idcLbNew(1:nh)));
        end
        f8v_idx1 = idc_lb(nh)+1;
    else
        f8v_idx1 = 1;
        hl = [];
    end
end
    
f8v = f8(f8v_idx1:end); % valid data section of f8
llta = num_lb - nh;     % number of non-header lines to analyse


% find out decimal character (. or ,)
SR = {};        % Init. replacement character string
SR_idx = 0;     % Init. counter of the above
sepchar = '';   % Init. separator (delimiter) character
decchar = '.';  % Init. decimal character (default)

num_values_per_line = -num_beg_digdotdig_per_line + num_beg_numbers_per_line;

% Are there commas? If yes, are they decimal commas or delimiters?
if any( num_kom_per_line(nh+1:end) > 0 ) 
    sepchar = ',';  % preliminary take comma for delimiter
    % Decimal commas are neighboured by two numeric digits ...
    % and between two commas there has to be another separator
    if  all(num_kom_per_line(nh+1:end) == num_beg_kombd_per_line(nh+1:end)) ... % Are all commas enclosed by numeric digits?
        && ~any(num_beg_digdotdig_per_line(nh+1:end) > 0) ...   % There are no numbers with dots?
        && ~any(idc_2kom(nh+1:end) > 0)                         % There is no pair of commas with no other separator inbetween?

        decchar = ',';
        sepchar = '';
        
        num_values_per_line = -num_beg_digkomdig_per_line + num_beg_numbers_per_line; % number of values per line
    end
end

% replacement string for replacements by spaces
% other separators
is_wo_k_found = ismember(sep_wo_k, f8v);  % Tab Space : ;
is_other_found= ismember(other,f8v);      % other printable ASCIIs

% possible replacement string to replace : and ;
sr1 = [sepchar, char(sep_wo_k([0 0 1 1 1]&is_wo_k_found))];   
% possible replacement string to replace other characters
sr2 = char(other(is_other_found));        % still obsolete as such lines are treated as header lines

if numel([sr1,sr2])>0
    SR_idx = SR_idx + 1;
    SR{SR_idx} = [sr1, sr2, ' '];
end

% possible replacement string to replace the decimal character
if strcmp(decchar,',')
    SR_idx = SR_idx + 1;
    SR{SR_idx} = ',.';
end

num_items_per_line = num_values_per_line + num_beg_nan_per_line;

nc = max(num_items_per_line(nh+1:end));    % proposed number of columns

if isempty(nc)
    aerrmsg = 'no numeric data found';
    return
end

% suggest a proper read mode depending on uniformity of the number of values per
% line
if numel(unique(num_items_per_line(nh+1:end))) > 1
    RM = 'line';
    nc = -nc;
else
    RM = 'auto';
end

%% : : : : : further subfunctions : : : : : 

function s = strcatcell(C)

% STRCATCELL Concatenate strings of a 1D/2D cell array of strings
%
% C = {'a ','123';'b','12'}
%   C = 
%     'a '    '123'
%     'b'     '12' 
% s = strcatcell(C)
%   s =
%     a 123
%     b 12 

num_col = size(C,2);
D = cell(1,num_col);
for idx = 1:num_col
    D{idx} = char(C{:,idx});
end
s = [D{:}];

function [L,R] = neighbours(a,b)

% NEIGHBOURS find nearest neighbours in a given set of values
% 
% [L,R] = neighbours(a,b)
%
% find neighbours of elements of a in b:
% L(i): b(i) with a(i)-b minimal, a(i)-b >0 (left neighbour)
% R(i): b(i) with b-a(i) minimal, b-a(i)>=0 (right neighbour)
% 
% If no left or right neighbour matching the above criteria can be found
% in b, -Inf or Inf (respectively) will be returned.
%
%
% EXAMPLE:
% [L,R] = neighbours([-5, pi, 101],[-5:2:101])
% 
% L =
%   -Inf
%      3
%     99
% R =
%     -5
%      5
%    101

% todo: check if there's a better solution with histc

len_a = length(a);
ab    = [a(:);-Inf;b(:);Inf];

[ab,ix] = sort(ab);
[ix,jx] = sort(ix);

L = ab(max(1,jx(1:len_a)-1));
R = ab(jx(1:len_a)+1);

function [w, newidcoi, vi] = cutvec(v,li,hi,doKeep,vn,varargin)

% CUTVEC cut out multiple sections from a vector by index ranges
%
% Syntax:
%   w = cutvec(v,li,hi,doKeep,vn)
% OR
%   [w, new_idc_oi, vi] = ...
%       cutvec(v,li,hi,doKeep,vn,old_idc_oi)
%
% v             input vector
% w             output vector consisting of v-sections
% li            lower limits of ranges (sorted!)
% hi            upper limits of ranges (sorted!)
% doKeep        true:   cut out values outside the ranges
%               false:  cut out values within the ranges
% vn            matlab version number as a scalar
% old_idc_oi    indices of interest in v
% new_idc_oi    corresponding indices of interest in w
% vi            logical matrix with w=v(vi)
%
% EXAMPLE:
%
% w = cutvec([1:20],[3,10,16],[7,12,19],1)
%
%   =>  w = [3 4 5 6 7   10 11 12   16 17 18 19]
%
% w = cutvec([1:20]*2,[3,10,16],[7,12,19],0)
%
%   =>  w = [2 4    16 18    26 28 30    40]
%
% tic, w = cutvec([1:5000000]',[100:500:5000000],[200:500:5000000],0); toc
% 
% elapsed_time =
% 
%     0.4380
% v = 1:20;
% li= [10,18];
% hi= [12,19];
% doKeep = 0;
% idcoi = [1,4,7,10,13,18,20];
% 
% [w, newidcoi, vi] = cutvec(v,li,hi,doKeep,idcoi)

%   $Revision: 1.10 $ 

len_v   = length(v);
k_flag  = logical(doKeep);
has_idcoi = false;
newidcoi=[];

if nargin == 6
    idcoi   = int32(varargin{1});
    if ~issorted(idcoi)
        error([mfilename ': vector of indices of interest must be sorted!'])
    end
    has_idcoi = true;
end

vi = endpoint2logical(len_v,li,hi,k_flag);

if has_idcoi
    if vn>=7
        remidc   = int32(find(vi));
    else
        remidc   = find(vi);
    end
    newidcoi = ismembc2(idcoi,remidc);
end

w = v(vi);


function vi = endpoint2logical(len,li,hi,doInclude)

% ENDPOINT2LOGICAL convert endpoints of index intervals to logical index
%
% Syntax:
%   vi = endpoint2logical(len,li,hi,doInclude)
%
% with
%
% len           length of logical index vector
% li            vector with lower  endpoints of linear index intervals
% hi            vector with higher endpoints of linear index intervals
% doInclude     true:  logical indices are 1 only inside  the intervals
%               false: logical indices are 1 only outside the intervals
%
% vi            logical index vector

% initialize output:
if doInclude
    vi = false(len,1);
else
    vi = true(len,1);
end

for i = 1:numel(li)
    vi(li(i):hi(i)) = doInclude;
end


function ia = argincheck(allargin)

% ARGCHECK check input arguments for txt2mat
%
% ia = argincheck(allargin)
% provides input argument information in struct ia with fields
%       ia.is_argin_num_header
%       ia.num_header
%       ia.is_argin_num_colon
%       ia.num_colon
%       ...

% Check input argument occurence (Property/Value-pairs)
%  1 'NumHeaderLines',     Scalar,     13
%  2 'NumColumns',         Scalar,     100
%  3 'ConvString',         String,     ['%d.%d.%d' repmat('%f',1,6)]
%  4 'ReplaceChar',        CellAString {')Rx ',';: '}
%  5 'BadLineString'       CellAString {'Warng', 'Bad'}
%  6 'ReplaceExpr',        CellAString {{'True','1'},{'False','0'},{'#Inf','Inf'}}
%  7 'DialogString'        String      'Now choose a Labview-Logfile'
%  8 'MemPar'              2x1-Vector  [2e7, 2e5]
%  9 'InfoLevel'           Scalar      2
% 10 'ReadMode'            String      'Auto'
% 11 'NumericType'         String      'single'
% 12 'RowRange'            2x1-Vector  [1,Inf]
% 13 'FilePos'             Scalar      1e5
% 14 'ReplaceRegExpr'      CellArOfStr {{'True','1'},{'False','0'},{'#Inf','Inf'}} 
% 15 'GoodLineString'      CellAString {'OK'}

ia.errmsg = '';

propnames   = {'NumHeaderLines','NumColumns','ConvString','ReplaceChar',...
               'BadLineString','ReplaceExpr','DialogString','MemPar',...
               'InfoLevel','ReadMode','NumericType','RowRange',...
               'FilePos','ReplaceRegExpr','GoodLineString'};
len_pn      = length(propnames);
proppos     = zeros(size(propnames));   % argument-no. Property-String
valpos      = zeros(size(propnames));   % argument-no. Value

% compare the possible property strings to all arguments and save what
% can be found at which argument number to <proppos> and <valpos>
for adx = 2:length(allargin) %nargin    % look at all args but the first
    if ischar(allargin{adx})            % if it is a string...
        for pdx = 1:len_pn
            if isequal(lower(propnames{pdx}),lower(allargin{adx}))
                if proppos(pdx) ~= 0
                   ia.errmsg = ['Multiple occurence of ' propnames{pdx} ' argument.']; 
                   return
                end
                proppos(pdx) = adx;
                valpos(pdx)  = adx+1;
            end
        end
    end
end

% add argument numbers that have no property string, i.e. that occur
% before the first property string
firstproppos = min(proppos(proppos>0));
if isempty(firstproppos)
    for pdx = 2:length(allargin)
        valpos(pdx-1) = pdx;
    end % for
else
    for pdx = 2:firstproppos-1
        if proppos(pdx-1) ~= 0
            ia.errmsg = ['Multiple occurence of ' propnames{pdx-1} ' argument.']; 
            return
        end
        valpos(pdx-1) = pdx;
    end
end


% Check input argument contents
% todo: complete type checking
% ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
is_argin_num_header= false; % Init., is an argument for the number of header lines given?
if valpos(1) ~= 0
    num_header  = allargin{valpos(1)};
    if ~isempty(num_header)
        is_argin_num_header = true;
    end
else
    num_header = NaN;
end
% ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
is_argin_num_colon = false; % Init., is an argument for the number of data columns lines given?
if valpos(2) ~= 0
    num_colon   = allargin{valpos(2)};
    if ~isempty(num_colon)
        is_argin_num_colon = true;
    end
else
    num_colon = [];
end
% ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
%is_argin_conv_str  = false; % Init., conversion string argument given?
if valpos(3) ~= 0
    conv_str    = allargin{valpos(3)};
    if isempty(conv_str)
        conv_str = '%f';
    %else
    %    is_argin_conv_str = true;
    end
else
    %conv_str = {};
    conv_str = '%f';    % standard, as always returned by anatxt
end
% ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
% Check for character replacement argument. For compatibility reasons,
% multiple strings as separate arguments are still supported.
has_sr_input_only = false;
sr_input_ca = {};
if valpos(4) ~= 0
    if iscellstr(allargin{valpos(4)})
        sr_input_ca = allargin{valpos(4)};
    elseif ischar(allargin{valpos(4)});
        sr_input_ca = {allargin{valpos(4):end}};
        disp([mfilename ': for future versions, please use a single cell array of strings as an input argument for multiple replacement strings.'])
        has_sr_input_only = true;
    else
        ia.errmsg = 'replacement string argument must be of type string or cell array of strings'; 
        return
    end
    num_sr      = length(sr_input_ca);
else
    num_sr      = 0;
end
% ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
if valpos(5) ~= 0 && ~has_sr_input_only     % bad line strings
    if iscellstr(allargin{valpos(5)})
        kl_input_ca = allargin{valpos(5)};      
    elseif ischar(allargin{valpos(5)});
        kl_input_ca = {allargin{valpos(5)}};
        disp([mfilename ': for future versions, please use a single cell array of strings as an input argument for bad line marker strings.'])
    else
        ia.errmsg = 'bad line marker argument must be of type string or cell array of strings'; 
        return
    end
    num_kl      = length(kl_input_ca);
else
    num_kl      = 0;
    kl_input_ca = {};
end
% ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
if valpos(6) ~= 0   % 'ReplaceExpression'
    replace_expr = allargin{valpos(6)};
    num_er       = length(replace_expr);
else
    replace_expr = {};
    num_er       = 0;
end
% ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
if valpos(7) ~= 0           % 'DialogString'
    dialog_string = allargin{valpos(7)};
else
    dialog_string = 'Choose a data file';
end
% ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
if valpos(8) ~= 0           % 'MemPar'
    mem_par  = allargin{valpos(8)};
    if numel(mem_par)==2
        warning('txt2mat:NonScalarBufferArgument', ...
                'A positive integer scalar is expected as MemPar argument. The second value has become obsolete.')
    elseif numel(mem_par)>2 || numel(mem_par)==0
        error('MemPar argument must be scalar.')
    end
    if rem(mem_par(1),1)~=0 || mem_par(1) <= 0
        error('MemPar argument must be a positive integer.')
    end
    idx_rng  = mem_par(1);
    %ldx_rng  = mem_par(2);
else
    idx_rng  = 65536; % default number of characters to be processed simultaneously
end
% ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
if valpos(9) ~= 0           % 'InfoLevel'
    infolvl  = allargin{valpos(9)};
else
    infolvl  = 2;
end
% ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
if valpos(10) ~= 0          % 'ReadMode'
    readmode = allargin{valpos(10)};
    is_argin_readmode = true;
    % force readmode to 'line' if num_colon < 0
    if is_argin_num_colon && num_colon < 0 && ~strcmpi(readmode,'line');
        readmode = 'line';
        warning('txt2mat:ineptReadmode', ...
            'ReadMode is set to ''line'' as NumColumns was given as negative.') 
    end
else
    is_argin_readmode = false;
    if is_argin_num_colon && num_colon < 0;
        readmode = 'line';
    else
        readmode = 'auto';
    end
end
% ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
if valpos(11) ~= 0       	% 'NumericType'
    numerictype = allargin{valpos(11)};
else
    numerictype = 'double';
end
% ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
if valpos(12) ~= 0          % 'RowRange'
    rowrange = allargin{valpos(12)};
    if ~(numel(rowrange)==2) || ~issorted(rowrange) || rowrange(1)<1 || ...
        (rem(rowrange(1),1)~=0) || ( (rem(rowrange(2),1)~=0) && (rowrange(2)~=Inf) )
        ia.errmsg = 'RowRange argument must be a sorted positive integer 2x1 vector.'; 
        return
    end
    is_argin_rowrange = true;
else
    is_argin_rowrange = false;	
    rowrange = [1,Inf];
end
% ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
if valpos(13) ~= 0          % 'FilePos'
    filepos = allargin{valpos(13)};
    if filepos<0 || (rem(filepos,1)~=0)
        ia.errmsg = 'FilePos argument must be a nonnegative integer.'; 
        return
    end
    is_argin_filepos = true;
else
    is_argin_filepos = false;
    filepos = 0;
end
% ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
if valpos(14) ~= 0   % 'ReplaceRegExpr'
    replace_regex= allargin{valpos(14)};
    num_rr       = length(replace_regex);
else
    replace_regex= {};
    num_rr       = 0;
end
% ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
if valpos(15) ~= 0      % 'GoodLineString'
    if iscellstr(allargin{valpos(15)})
        gl_input_ca = allargin{valpos(15)};      
    else
        ia.errmsg = 'good line marker argument must be of type cell array of strings'; 
        return
    end
    num_gl      = length(gl_input_ca);
    is_argin_gl = true;
    
    % todo: check for conversion string
    
else
    num_gl      = 0;
    gl_input_ca = {};
    is_argin_gl = false;
end% ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

% handle file name argument

% 1) no file or path name is given -> open file dialogue
if numel(allargin) == 0 || isempty(allargin{1})
    [filn,pn] = uigetfile('*.*', dialog_string);
    ffn = fullfile(pn,filn);
% 2) a path name is given -> open file dialogue with *.* filter spec
elseif exist(allargin{1},'dir') == 7
    curcd = cd;
    cd(allargin{1});                   
    [filn,pn] = uigetfile('*.*', dialog_string);
    ffn = fullfile(pn,filn);
    cd(curcd);
% 3) a valid file name is given -> take it as it is
elseif exist(allargin{1},'file') 
    ffn  = allargin{1};
	[dum_pathstr,name,ext] = fileparts(ffn);
	filn = [name,ext];
% 4) an asterisk in the file name -> open file dialogue, use filter spec
%    - OR -
%    nonexisting file -> produce error message and return
else
    [pathstr, name, ext] = fileparts(allargin{1});
    doOpenDialog = (isempty(pathstr) || exist(pathstr,'dir')==7) && ...
                   numel(strfind([name, ext], '*'))>0;
               
    if doOpenDialog
        if ~isempty(pathstr)
            curcd = cd;
            cd(pathstr)
        end
        
        [filn,pn] = uigetfile({[name, ext];'*.*'}, dialog_string);
        ffn = fullfile(pn,filn);
        
        if ~isempty(pathstr)
            cd(curcd);
        end
    else
        % wrong name
        ia.errmsg = 'no such file or directory'; 
        return
    end
end

% generate a shortened form of the file name:
if length(filn) < 28
    ffn_short = filn;
else
    ffn_short = ['...' filn(end-17:end)];
end

ia.is_argin_num_header 	= is_argin_num_header;
ia.num_header          	= num_header;
ia.is_argin_num_colon  	= is_argin_num_colon;
ia.num_colon          	= num_colon;
ia.conv_str           	= conv_str;
ia.sr_input_ca        	= sr_input_ca;
ia.num_sr              	= num_sr;
ia.kl_input_ca        	= kl_input_ca;
ia.num_kl               = num_kl;
ia.replace_expr         = replace_expr;
ia.num_er               = num_er;
ia.idx_rng              = idx_rng;
ia.infolvl              = infolvl;
ia.is_argin_readmode    = is_argin_readmode;
ia.readmode             = readmode;
ia.numerictype          = numerictype;
ia.is_argin_rowrange    = is_argin_rowrange;
ia.rowrange             = rowrange;
ia.filepos              = filepos;
ia.is_argin_filepos     = is_argin_filepos;
ia.replace_regex        = replace_regex;
ia.num_rr               = num_rr;
ia.ffn                  = ffn;
ia.ffn_short            = ffn_short;
ia.num_gl               = num_gl;
ia.gl_input_ca          = gl_input_ca;
ia.is_argin_gl          = is_argin_gl;


function lb = detectLineBreakCharacters(ffn)

% DETECTLINEBREAKCHARACTERS find out type of line termination of a file
%
% lb = detectLineBreakCharacters(ffn)
%
% with
%   ffn     ascii file name
%   lb      line break character(s) as uint8, i.e.
%           [13 10]     (cr+lf) for standard DOS / Windows files
%           [10]        (lf) for Unix files
%           [13]        (cr) for Mac files
%
% The DOS style values are returned as defaults if no such line breaks are
% found.

% www.editpadpro.com/tricklinebreak.html :
% Line Breaks in Windows, UNIX & Macintosh Text Files
% A problem that often bites people working with different platforms, such
% as a PC running Windows and a web server running Linux, is the different
% character codes used to terminate lines in text files. 
% 
% Windows, and DOS before it, uses a pair of CR and LF characters to
% terminate lines. UNIX (Including Linux and FreeBSD) uses an LF character
% only. The Apple Macintosh, finally, uses a CR character only. In other
% words: a complete mess.

lfuint   = uint8(10);   % LineFeed
cruint   = uint8(13);   % CarriageReturn
crlfuint = [cruint,lfuint];
lfchar   = char(10);
crchar   = char(13);
crlfchar = [crchar,lfchar];
readlen  = 16384;

% Cycle through file and read until we find line termination characters or
% we reach the end of file. 
% Possible line breaks are: cr+lf (default), lf, cr

logfid = fopen(ffn); 
has_found_lbs = false;
while ~has_found_lbs

    [f8,cntr] = fread(logfid,readlen,'*char');

    pos_crlf = strfind(f8',crlfchar);
    pos_lf   = strfind(f8',lfchar);
    pos_cr   = strfind(f8(1:end-1)',crchar);
    % here we ignored a cr at the end as it might belong to a cr+lf
    % combination (later we'll step back one byte in the file position to
    % avoid overlooking such a single cr)

    num_lbs = [numel(pos_crlf),numel(pos_lf),numel(pos_cr)];

    if all(num_lbs==0)
        fseek(logfid, -1, 0);    % step back one byte
        
        % if we reached the end of file without finding any special
        % character, set the endmost line break character and the complete
        % line break character to DOS values as defaults
        if cntr < readlen
            has_found_lbs = true;   % just to exit the while loop
            lb = crlfuint;          % complete line break character set
        end
    elseif num_lbs(1)>0
        has_found_lbs = true;
        lb = crlfuint;
    elseif num_lbs(2)>0
        has_found_lbs = true;
        lb = lfuint;
    elseif num_lbs(3)>0
        has_found_lbs = true;
        lb = cruint;
    end
end
fclose(logfid); 

function [idcLb, cntLb, secLbIdc, idcBad, idcGood] = FindLineBreaks(f8, uintLb, ...
    lenSection, doFindAll, doCount, numBad, badStrings, numGood, goodStrings) 

% FINDLINEBREAKS find line break indices and bad line positions
%
% [idcLb, cntLb, secLbIdc, idcBad] = ...
%               FindLineBreaks(f8, uintLb, lenSection, ...
%                              doFindAll, doCount, numBad, badStrings)
%
% This function cycles through a text by manageable sections and finds line
% break characters - either all or just the last one in each section - and,
% if necessary, looks for 'bad line' keyword strings. If only the last line
% break in each section is to be found, FindLineBreaks can provide the
% corresponding consecutive number of this line break in the text.
%
% idcLb     	(nx1)-vector. Zero + some or all line break positions in f8
% cntLb         empty or (nx1)-vector. If not all line breaks have to be
%               found, but doCount is true, this is the number of of each
%               line break in f8 that is listed in idcLb (with a zero put
%               in front). Otherwise cntLb is left empty, as cntLb would
%               just be trivially [0:numel(idcLb)]
% secLbIdc      idcLb(secLbIdc) are the positions of the last line
%               break in each section (including the "zero" line break)
% idcBad        position of the beginning of a bad line marker string
% idcGood       position of the beginning of a good line marker string
%
% f8            the text as an uint8 (Nx1)-vector
% uintLb        uint8-scalar representation of the line break character to
%               be found (10 or 13; could actually be any character). 
% lenSection   	character length of a section
% doFindAll     true: find and index every line break; false: find only the
%               last one in a section
% doCount       count number of every line break in cntLb - this is active
%               only in the non-trivial case when only the last line
%               break in a section has to be found 
% numBad        number of supplied bad (i.e. skippable) line strings. To
%               look for such strings, numBad>0 AND doFindAll=true are
%               required
% badStrings    cell array containing the bad line marker strings.
%               FindLineBreaks will look for the strings in
%               badStrings(1:numBad) 
% goodStrings   cell array containing the good line marker strings.

%   $Revision: 3.50 $ 

lenF8   = numel(f8);
idxLo 	= 1;   % init., start index of a section processed in a loop
idcLb   = 0;
idcBad 	= [];  % init., will contain the indices of bad line markers strings
idcGood	= [];  % init., will contain the indices of good line markers strings
cntLb   = [];

numSection = ceil(lenF8/lenSection);

if numBad>0
    % numExtraCharBad will define an interval around a section's end to be
    % additionally searched for bad line marker strings (see below)
    numExtraCharBad = zeros(numBad,1);
    for idx = 1:numBad
        numExtraCharBad(idx) = max(0,numel(badStrings{idx})-1);
    end
end
if numGood>0
    % numExtraCharGood will define an interval around a section's end to be
    % additionally searched for good line marker strings
    numExtraCharGood = zeros(numGood,1);
    for idx = 1:numGood
        numExtraCharGood(idx) = max(0,numel(goodStrings{idx})-1);
    end
end

if doFindAll    % ~~~~~~~~~~~~ find all line break positions ~~~~~~~~~~~~~~
    % In what follows, the text will repeatedly be processed in consecutive
    % sections of length <lenSection> to help avoid memory problems.
    secLbIdc = ones(numSection+1,1); 
    loopCntr = 0;
    while idxLo <= lenF8
        loopCntr = loopCntr + 1;
        idxHi = min(idxLo - 1 + lenSection,lenF8);	% end index of current section

        % Check for possible good/bad line markers and find line breaks
        if numBad+numGood>0
            f8Curr = f8(idxLo:idxHi);      	% current working section 
            for idx = 1:numBad            	% find positions of all bad markers
                % position of markers in current section:
                idcBadCurr = strfind(char(f8Curr'),badStrings{idx})';
                if numExtraCharBad(idx)>0 && idxHi<lenF8
                    % care for strings of more than one character that
                    % could partially fall into the beginning of the
                    % following section, so find such strings at positions
                    % (1-numExtraCharBad:numExtraCharBad) around the end of the
                    % section:
                    startExtraSection = max(idxHi-numExtraCharBad(idx)+1,1);
                    endExtraSection   = min(idxHi+numExtraCharBad(idx),lenF8);
                    idcBadCurr = [idcBadCurr; lenSection-numExtraCharBad(idx) ...
                                  + strfind( char(f8(startExtraSection:endExtraSection).'),  ...
                                  badStrings{idx})]; %#ok<AGROW>
                end
                tdcBad = [idcBad; idcBadCurr + idxLo-1]; % temporary index
                idcBad = tdcBad;
            end % for
            for idx = 1:numGood            	% find positions of all good markers
                % position of markers in current section:
                idcGoodCurr = strfind(char(f8Curr'),goodStrings{idx})';
                if numExtraCharGood(idx)>0 && idxHi<lenF8
                    % care for strings of more than one character as above:
                    startExtraSection = max(idxHi-numExtraCharGood(idx)+1,1);
                    endExtraSection   = min(idxHi+numExtraCharGood(idx),lenF8);
                    idcGoodCurr = [idcGoodCurr; lenSection-numExtraCharGood(idx) ...
                                  + strfind( char(f8(startExtraSection:endExtraSection).'),  ...
                                  goodStrings{idx})]; %#ok<AGROW>
                end
                tdcGood = [idcGood; idcGoodCurr + idxLo-1]; % temporary index
                idcGood = tdcGood;
            end % for
            isLb = f8Curr==uintLb;
            
        else
            isLb= f8(idxLo:idxHi)==uintLb;
        end

        % collect line break indices
        tdcLb = [idcLb; find(isLb)+idxLo-1];	% use tdcLb temporarily to ...
        idcLb = tdcLb;                          % avoid memory fragmentation (?)
        
        secLbIdc(loopCntr+1) = numel(idcLb);
        
        idxLo = idxHi + 1;                      % start index for the following loop
        
    end % while
    
else    % ~~~~~~ find last line break position of each section only ~~~~~~~

    % Preallocate maximum space for output variables:
    if doCount
        cntLb = zeros(numSection+1,1);
    end
    idcLb = zeros(numSection+1,1);
    
    countLbPos = 0; % keep in mind how many line break positions have been
                    % found, as some sections might not contain a line
                    % break at all

    % Find line break indices within lenSection distance
    while idxLo <= lenF8
        idxHi = min(idxLo - 1 + lenSection,lenF8);   % end index of current section

        % parse backwards to find the last line break of the section
        cntr = 0;
        doKeepOnLooking = true;
        while doKeepOnLooking
            hasNotFound = (f8(idxHi-cntr) ~= uintLb);
            cntr = cntr+1;
            doKeepOnLooking = hasNotFound && (cntr < lenSection);
        end
        
        if ~hasNotFound
            countLbPos = countLbPos + 1;
            % add the line break to the list
            idcLb(countLbPos+1) = idxHi-cntr+1;
            
            % if desired, count all line breaks of the section
            if doCount
                cntLb(countLbPos+1)= cntLb(countLbPos) + sum(f8(idxLo:idxHi)==uintLb); %#ok<AGROW>
            end
        end
        idxLo = idxHi + 1;
    end % while 
    
    % if too much space was preallocated, shorten the outputs:
    if countLbPos<numSection
        idcLb(countLbPos+2:numSection+1) = [];
        if doCount
            cntLb(countLbPos+2:numSection+1) = [];
        end
    end
    
    secLbIdc = (1:numel(idcLb)).';
    
end     % ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

function [A,a] = InitializeMatrix(numRows,numColumns,numericType,doSetNan,vn)

% INITIALIZEMATRIX initialize result matrix A depending on matlab version
%
% [A,a] = InitializeMatrix(numRows,numColumns,numericType,...
%                          doSetNan, matlabVersionNumber);
%
% A                     numRows x numColumns - Matrix
% a                     scalar of the same type a A
%
% numRows               nonnegative integer
% numColumns            nonnegative integer
% numericType           numeric type string ('double','single',...)
% doSetNan              logical - if true, set outputs to NaNs rather than
%                       zeros if the numericType allows NaNs
% matlabVersionNumber   scalar


if vn>=7
    if doSetNan && (strcmpi(numericType,'double') || ...
                    strcmpi(numericType,'single'))
        A = NaN(numRows,numColumns,numericType);
        a = NaN;
    else
        A = zeros(numRows,numColumns,numericType);
        a = 0;
    end
else
    if strcmpi(numericType,'double')
        if doSetNan
            A = NaN*zeros(numRows,numColumns);
            a = NaN;
        else
            A = zeros(numRows,numColumns);
            a = 0;
        end
    else
        % create a single row of A to be repeated if numericType is
        % other than double:
        Ar= zeros(1,numColumns);
        switch lower(numericType)
            case 'single'
                if doSetNan
                    A = repmat(single(NaN*Ar),numRows,1);
                    a = single(NaN);
                else
                    A = repmat(single(Ar),numRows,1);
                    a = single(0);
                end
            case 'int8'
                A = repmat(int8(Ar),numRows,1);
                a = int8(0);
            case 'int16'
                A = repmat(int16(Ar),numRows,1);
                a = int16(0);
            case 'int32'
                A = repmat(int32(Ar),numRows,1);
                a = int32(0);
            case 'int64'
                A = repmat(int64(Ar),numRows,1);
                a = int64(0);
            case 'uint8'
                A = repmat(uint8(Ar),numRows,1);
                a = uint8(0);
            case 'uint16'
                A = repmat(uint16(Ar),numRows,1);
                a = uint16(0);
            case 'uint32'
                A = repmat(uint32(Ar),numRows,1);
                a = uint32(0);
            case 'uint64'
                A = repmat(uint64(Ar),numRows,1);
                a = uint64(0);
        end
    end
end


function f8 = cleanUpFinalWhitespace(f8,lbfull)

% CLEANUPFINALWHITESPACE replace final whitespaces by spaces + line break
%
% f8 = cleanUpFinalWhitespace(f8,lbfull)
% with
% f8        text as uint8-vector
% lbfull    full line break characters as uint8-vector

spuint   = uint8(32);   % Space (= ascii whitespace limit) as uint8
num_lbfull = numel(lbfull); 
cnt_trail_white = 0;
is_ws_at_end = true;

while is_ws_at_end  % step through the endmost characters
    if f8(end-cnt_trail_white) <= spuint        % is it a whitespace?
        cnt_trail_white = cnt_trail_white + 1;
    else
        f8(end-cnt_trail_white+1:end) = spuint;	% fill with spaces
        if cnt_trail_white >= num_lbfull
            % replace endmost space(s) by a line break:
            f8(end-num_lbfull+(1:num_lbfull))  = lbfull;    
        else
            % append a final line break:
            f8(end+(1:num_lbfull))  = lbfull;               
        end
        is_ws_at_end = false;
    end
end % while
