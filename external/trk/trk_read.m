function [header,tracks] = trk_read(filePath)
%TRK_READ - Load TrackVis .trk files
%TrackVis displays and saves .trk files in LPS orientation. After import, this
%function attempts to reorient the fibers to match the orientation of the
%original volume data.
%
% Syntax: [header,tracks] = trk_read(filePath)
%
% Inputs:
%    filePath - Full path to .trk file [char]
%
% Outputs:
%    header - Header information from .trk file [struc]
%    tracks - Track data structure array [1 x nTracks]
%      nPoints - # of points in each streamline
%      matrix  - XYZ coordinates (in mm) and associated scalars [nPoints x 3+nScalars]
%      props   - Properties of the whole tract (ex: length)
%
% Example:
%    exDir           = '/path/to/along-tract-stats/example';
%    subDir          = fullfile(exDir, 'subject1');
%    trkPath         = fullfile(subDir, 'CST_L.trk');
%    [header tracks] = trk_read(trkPath);
%
% Other m-files required: none
% Subfunctions: get_header
% MAT-files required: none
%
% See also: http://www.trackvis.org/docs/?subsect=fileformat
%           http://github.com/johncolby/along-tract-stats/wiki/orientation

% Author: John Colby (johncolby@ucla.edu)
% UCLA Developmental Cognitive Neuroimaging Group (Sowell Lab)
% Mar 2010

% Parse in header
fid    = fopen(filePath, 'r');
header = get_header(fid);

% Check for byte order
if header.hdr_size~=1000
    fclose(fid);
    fid    = fopen(filePath, 'r', 'b'); % Big endian for old PPCs
    header = get_header(fid);
end

if header.hdr_size~=1000, error('Header length is wrong'), end

% Check orientation
[maxX, ix] = max(abs(header.image_orientation_patient(1:3)));
[maxY, iy] = max(abs(header.image_orientation_patient(4:6)));
% Martin: Bugfix here when image_orientation_patient is empty...
if maxX == 0 && maxY == 0
    ix = 1;
    iy = 2;
    iz = 3;
else
    iz = 1:3;
    iz([ix iy]) = [];
end

% Fix volume dimensions to match the reported orientation.
header.dim        = header.dim([ix iy iz]);
header.voxel_size = header.voxel_size([ix iy iz]);

% Parse in body
if header.n_count > 0
	max_n_trks = header.n_count;
else
	% Unknown number of tracks; we'll just have to read until we run out.
	max_n_trks = inf;
end

% It's impossible to preallocate the "tracks" variable because we don't
% know the number of points on each curve ahead of time; we find out by
% reading the file.  The line below suppresses preallocation warnings.
%#ok<*AGROW>

iTrk = 1;
while iTrk <= max_n_trks
	pts = fread(fid, 1, 'int');
	if feof(fid)
		break;
	end
    tracks(iTrk).nPoints = pts;
    tracks(iTrk).matrix  = fread(fid, [3+header.n_scalars, tracks(iTrk).nPoints], '*float')';
    if header.n_properties
        tracks(iTrk).props = fread(fid, header.n_properties, '*float');
    end
    
    % Modify orientation of tracks (always LPS) to match orientation of volume
    coords = tracks(iTrk).matrix(:,1:3);
    coords = coords(:,[ix iy iz]);
    if header.image_orientation_patient(ix) < 0
        coords(:,ix) = header.dim(ix)*header.voxel_size(ix) - coords(:,ix);
    end
    if header.image_orientation_patient(3+iy) < 0
        coords(:,iy) = header.dim(iy)*header.voxel_size(iy) - coords(:,iy);
    end
    tracks(iTrk).matrix(:,1:3) = coords;
	iTrk = iTrk + 1;
end

if header.n_count == 0
	header.n_count = length(tracks);
end

fclose(fid);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function header = get_header(fid)

header.id_string                 = fread(fid, 6, '*char')';
header.dim                       = fread(fid, 3, 'short')';
header.voxel_size                = fread(fid, 3, 'float')';
header.origin                    = fread(fid, 3, 'float')';
header.n_scalars                 = fread(fid, 1, 'short')';
header.scalar_name               = fread(fid, [20,10], '*char')';
header.n_properties              = fread(fid, 1, 'short')';
header.property_name             = fread(fid, [20,10], '*char')';
header.vox_to_ras                = fread(fid, [4,4], 'float')';
header.reserved                  = fread(fid, 444, '*char');
header.voxel_order               = fread(fid, 4, '*char')';
header.pad2                      = fread(fid, 4, '*char')';
header.image_orientation_patient = fread(fid, 6, 'float')';
header.pad1                      = fread(fid, 2, '*char')';
header.invert_x                  = fread(fid, 1, 'uchar');
header.invert_y                  = fread(fid, 1, 'uchar');
header.invert_z                  = fread(fid, 1, 'uchar');
header.swap_xy                   = fread(fid, 1, 'uchar');
header.swap_yz                   = fread(fid, 1, 'uchar');
header.swap_zx                   = fread(fid, 1, 'uchar');
header.n_count                   = fread(fid, 1, 'int')';
header.version                   = fread(fid, 1, 'int')';
header.hdr_size                  = fread(fid, 1, 'int')';
