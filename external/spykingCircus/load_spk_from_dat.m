% LOAD_SPK_FROM_DAT     and detrend
%
% CALL                  SPK = LOAD_SPK_FROM_DAT( FILEBASE, SHANKNUM, CLUNUM )
%
% GETS                  FILEBASE    dat file assumed to be FILEBASE.dat
%                       SHAKNUM     
%                       CLUNUM      clu number/list of spike times/empty (all spikes in res file)
%                       SPKSUFFIX   {'spr'}, 'spk'; if empty - saves temporarily to PWD and deletes upon exist
%                       CLUSUFFIX   {'clu'}
%
% REQUIRES              dat, xml file
%                       res file/list of spike times
%                       for loading spikes of a specific cluster - clu file
%
% DOES                  -determines the parameters from the xml file;
%                       -determines the spike times from the res/clu files
%                       or from the list given in CLUNUM (at the data
%                       sampling frequency);
%                       -loads the spikes at these times
%                       -removes DC and trends
%                       -(optional) saves the spikes to an spk/spr file (spikes-raw)
%                       -(optional) loads those spikes
%
% CALLS                 LOADXML, READBIN, MYDETREND
%
% NOTES                 1. uses a procesing buffer of 1000 spikes
%                       2. channel order is kept as in xml file

% 28-apr-11 ES, 10-june-2015 Adrien Peyrache. change nSample and nPeak
% options

% revisions
% 02-may-11 case of zero spikes handled

function [ spk, rc ] = load_spk_from_dat( filebase, shanknum, clunum, spksuffix, clusuffix, resoffset , Fs0)

% arguments
nargs = nargin;
nout = nargout;
if nargs < 3, clunum = []; end
if nargs < 4, spksuffix = 'spr'; end % 'spk'
if nargs < 5 || isempty( clusuffix ), clusuffix = 'clu'; end % 'clc' 
if nargs < 6 || isempty( resoffset ), resoffset = 0; end

% constants
source = 'int16'; 
target = 'single';
PEAKSAMPLE = 16;    % in case not defined in the par file. Set at 0 to use par values or default (16)
NSAMPLES = 40;      % in case not defined in the par file. Set at 0 to use par values or default (32)
% Fs0 = 30000;
blocksize = 100000;   % spikes; e.g. 10 x 32 x 100000 x 4 bytes = 12.5 MB

% output
spk = [];
rc = 0;

% file names
datfname = sprintf( '%s.dat', filebase );
resfname = sprintf( '%s.res.%d', filebase, shanknum );
xmlfname = sprintf( '%s.xml', filebase );
clufname = sprintf( '%s.%s.%d', filebase, clusuffix, shanknum );
if isempty( spksuffix )
    if nout == 0
        return
    end
    spkfname = sprintf( 'datspks.spr' ); % temporary file in PWD
else
    spkfname = sprintf( '%s.%s.%d', filebase, spksuffix, shanknum );
end
if ~exist( datfname, 'file' ) || ~exist( xmlfname, 'file' )
    error( 'missing source (dat/xml) file/s' )
end

% load parameters
par = LoadXml( xmlfname );
chans = par.SpkGrps( shanknum ).Channels + 1;
totchans = par.nChannels;
nchans = length( chans );
spkFs = par.SampleRate;

if PEAKSAMPLE ==0
    if isfield( par.SpkGrps( shanknum ), 'PeakSample' )
        peaksample = par.SpkGrps( shanknum ).PeakSample;
    else
        PEAKSAMPLE = 16;
        fprintf( 1, '%s, shank %d: Missing field peakSample; using default value (%d)\n'...
            , filebase, shanknum, round( PEAKSAMPLE * spkFs / Fs0 ) );
        peaksample = round( PEAKSAMPLE * spkFs / Fs0 );
    end
else
    peaksample = PEAKSAMPLE;
end

if NSAMPLES == 0
    if isfield( par.SpkGrps( shanknum ), 'nSamples' )
        nsamples = par.SpkGrps( shanknum ).nSamples;
    else
        NSAMPLES = 32;
        fprintf( 1, '%s, shank %d: Missing field nSamples; using default value (%d)\n'...
            , filebase, shanknum, round( NSAMPLES * spkFs / Fs0 ) );
        nsamples = round( NSAMPLES * spkFs / Fs0 );
    end
else
    nsamples = NSAMPLES;
end
% get spike times
if isempty( clunum ) % get times from res file
    if ~exist( resfname, 'file' )
        fprintf( 'missing source (res) file' )
        return
    end
    res = load( resfname );
    tim = res;
elseif length( clunum ) == 1 % get times from res, cluster identity from clu
    if ~exist( clufname, 'file' ) || ~exist( resfname, 'file' ) 
        error( 'missing source (clu/res) file/s' )
    end
    res = load( resfname );
    clu = load( clufname );
    clu( 1 ) = [];
    tim = res( clu == clunum );
else % get times from an external array
    tim = clunum( : );
end
if tim ~= round( tim )
    error( 'integer times only' )
end
if resoffset ~= 0
    tim = tim + resoffset;
    tim( tim < 0 ) = [];
end
nspikes = size( tim, 1 ); 
if nspikes == 0
    fprintf( 1, '%s, shank %d: No relevant spikes\n', filebase, shanknum );
    return
end
periods = tim * [ 1 1 ] + ones( nspikes, 1 ) * [ -peaksample + 1 nsamples - peaksample ];

% work in blocks
t0 = clock;
fprintf( 1, '%s: %d spikes', spkfname, nspikes )
nperiods = size( periods, 1 );
nblocks = ceil( nperiods / blocksize );
fp = fopen( spkfname, 'wb' );
if fp == -1
    fprintf( 'error opening file %s for writing', spkfname )
    rc = rc + 1;
    return
end
for i = 1 : nblocks
    fprintf( 1, '.' )
    bidx = ( ( i - 1 ) * blocksize + 1 )  : min( i * blocksize, nperiods );
    nspikesb = length( bidx );
    % load spikes
    if i == 1 && periods( bidx( 1 ) ) < 0 % first spike
        spk1 = readbin( datfname, chans, totchans, [ 1 periods( bidx( 1 ), 2 ) ], source, target );
        spk1 = [ zeros( nchans, 1 - periods( bidx( 1 ), 1 ), target ) spk1 ];
        spk = readbin( datfname, chans, totchans, periods( bidx( 2 : end ), : ), source, target );
        spk = reshape( spk, [ nchans nsamples nspikesb - 1 ] );
        spk = cat( 3, spk1, spk );
%    elseif % last spike
    else % any other spike
        spk = readbin( datfname, chans, totchans, periods( bidx, : ), source, target );
        spk = reshape( spk, [ nchans nsamples nspikesb ] );
    end
    % detrend
    if 0
    for ci = 1 : nchans
        spk( ci, :, : ) = mydetrend( squeeze( spk( ci, :, : ) ) );
    end
    end
    % write to binary file
    data2 = reshape( spk, [ nchans nsamples * nspikesb ] );
    count = fwrite( fp, data2, source );
    if count ~= ( nspikesb * nsamples * nchans )
        rc = rc + 2;
        return
    end
end
fclose( fp );
fprintf( 1, 'done (%0.3g sec)\n', etime( clock, t0 ) )

% load the detrended spikes
if nout > 0
    precision = sprintf( '%s=>%s', source, target );
    fp = fopen( spkfname, 'r' );
    spk = fread( fp, [ nchans inf ], precision );
    fclose( fp );
    nspks = size( spk, 2 ) / nsamples;
    spk = reshape( spk, [ nchans nsamples nspks ] );
end

% remove temporary file (if existing)
if isempty( spksuffix )
    if isunix
        cmd = sprintf( '!rm %s', spkfname );
    else
        cmd = sprintf( '!del %s', spkfname );
    end
    eval( cmd )
end

return
