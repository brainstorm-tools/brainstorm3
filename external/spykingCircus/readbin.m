% READBIN           read data from binary file
% 
% GENERAL           optimized for huge files, multiple (dis)contiguous channels, and multiple (dis)contiguous periods
%
% FILE STRUCTURE    sample by sample; in each sample - channel by channel:
%
%                   c1t1 c2t1 ... cNt1 // sample 1
%                   c1t2 c2t2 ... cNt2 // sample 2
%                   ...
%                   c1tN c2tN ... cNtN // sample N
%
% CALL              DATA = READBIN( FNAME, CHANS, NCHANS, PERIODS, SOURCE, TARGET )
%
% GETS              FNAME       full file name
%                   CHANS       list of channels to load (1-based)
%                   NCHANS      total number of channels in fname
%                   PERIODS     [ startSample endSample1; ... ; startSampleN endSampleN]
%                   SOURCE      {'int16'}
%                   TARGET      {'single'}
%
% RETURNS           DATA        matrix of length( CHANS ) x sum( diff( PERIODS ) + 1 )
%
% CALLS             nothing
%
% SEE ALSO          READSPK
%
% NOTE              -channels out of range result in an error message
%                   -periods out of range are ignored (output is zeros for those periods)
%                   -this routine can also be used to load spks efficiently;
%                   however, see READSPK for a fast implementation

% HISTORY
% -readmulti: reads all channels, which is often unnecessary; also does not allow reading periods
% -LoadBinary: allows reading periods, but then loads data for all channels
% -bload allows reading efficiently contiguous channels and periods but requires repetitive fopen and fclose calls
% => a new routine is needed to enable fast and flexible loading of multiple periods and channels from huge files

% 28-apr-11 ES

% revisions
% 01-may-11 superficial modifications
% 10-oct-13 bug: last line of reordering the data was fine for flipped but
%               buggy for arbitrary order, 
%           also corrected for multiple idetical channels

function data = readbin( fname, chans, nchans, periods, source, target )

% arguments
nargs = nargin;
if nargs < 3 || isempty( fname ) || isempty( nchans ), error( 'missing arguments' ), end
if nchans <= 0 || nchans ~= round( nchans ), error( 'nchans should be a non-negative integer' ), end
if isempty( chans ), chans = 1 : nchans; end
chans = chans( : ).';
if sum( chans ~= round( chans ) ) || sum( chans <= 0 ) || sum( chans > nchans )
    error( 'chans should be non-negative integers smaller than nchans' )
end
if nargs < 4 || isempty( periods ), periods = []; end
if sum( sum( periods ~= round( periods ) ) ) || sum( sum( periods <= 0 ) ) || ~ismember( size( periods, 2 ), [ 0 2 ] )
    error( 'periods should be a 2-column matrix of non-negative integers' )
end
if nargs < 5 || isempty( source ), source = 'int16'; end
if nargs < 6 || isempty( target ), target = 'single'; end

% build the type casting string
precision = sprintf( '%s=>%s', source, target );

% determine number of bytes/sample/channel
a = ones( 1, 1, source );
sourceinfo = whos( 'a' );
nbytes = sourceinfo.bytes;

% check input file
if ~exist( fname, 'file' )
    fprintf( 1, 'missing file %s\n', fname )
    data = [];
    return
end
fileinfo = dir( fname );
totsamples = floor( fileinfo( 1 ).bytes / nbytes / nchans );

% parse channel list
[ chans chanidx ] = sort( chans );
achans = chans;
[ chans ign uchanidx ] = unique( achans );
grouping = cumsum( diff( [ chans( 1 ) chans ] ) > 1 ) + 1;
groupstart = chans( logical( [ 1 diff( grouping ) ] ) );        % 1st channel in each group
groupsize = hist( grouping, unique( grouping ) );               % number of channels in each group
ngroups = length( groupsize );                                  % number of groups
nskip = nbytes * ( nchans - groupsize );                        % skip the channels not read
chans2load = length( chans );                                   % total number of channels

% parse periods
if isempty( periods )
    periods = [ 1 totsamples ];
end
durs = diff( periods, 1, 2 ) + 1;
ridx = logical( sum( periods > totsamples, 2 ) );
if sum( ridx )
    fprintf( 1, 'removing %d periods from file %s\n', sum( ridx ), fname )
    periods( ridx, : ) = [];   % removed
end
nperiods = size( periods, 1 );

% initialize output
data = feval( target, zeros( chans2load, sum( durs ) ) );

% open file for reading
fp = fopen( fname, 'r' );
if fp == -1, error( 'fopen error' ), end

% enable periods & discontiguous channels
for gi = 1 : ngroups
    n = 0;
    precisionstr = sprintf( '%d*%s', groupsize( gi ), precision );
    groupidx = grouping == gi;
    for i = 1 : nperiods
        startposition = nbytes * ( groupstart( gi ) - 1 + nchans * ( periods( i, 1 ) - 1 ) ); % start at requested sample of requested channel
        datasize = [ groupsize( gi ) durs( i ) ];
        rc = fseek( fp, startposition, 'bof' );
        if rc, error( 'fseek error' ), end
        data1 = fread( fp, datasize, precisionstr, nskip( gi ) );
        data( groupidx, n + ( 1 : durs( i ) ) ) = data1;
        n = n + durs( i );
    end
end

% close file
fclose( fp );

% expand if not unique
if ~isequal( chans, achans )
    data = data( uchanidx, : );
end

% reorder if not sorted
if sum( diff( chanidx ) ~= 1 )
    [ ign chanidx ] = sort( chanidx );
    data = data( chanidx, : );
end

return

% EOF
