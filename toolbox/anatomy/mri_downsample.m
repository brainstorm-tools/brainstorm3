function sMri = mri_downsample( sMri, n )
% MRI_DOWNSAMPLE: Downsample the volume size by a factor n (integer)
%
% USAGE:  sMri = mri_downsample( sMri, n )
%         Cube = mri_downsample( Cube, n )

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2020 University of Southern California & McGill University
% This software is distributed under the terms of the GNU General Public License
% as published by the Free Software Foundation. Further details on the GPLv3
% license can be found at http://www.gnu.org/copyleft/gpl.html.
% 
% FOR RESEARCH PURPOSES ONLY. THE SOFTWARE IS PROVIDED "AS IS," AND THE
% UNIVERSITY OF SOUTHERN CALIFORNIA AND ITS COLLABORATORS DO NOT MAKE ANY
% WARRANTY, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF
% MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, NOR DO THEY ASSUME ANY
% LIABILITY OR RESPONSIBILITY FOR THE USE OF THIS SOFTWARE.
%
% For more information type "brainstorm license" at command prompt.
% =============================================================================@
%
% Authors: Francois Tadel, 2013-2018

% If input is a structure: Get cube
if isstruct(sMri)
    Cube = sMri.Cube;
else
    Cube = sMri;
end
% If volume is too small: error
if any(size(Cube) < 3) || (n <= 1)
    return
end

% Get current size
% oldSize = size(Cube);
% Create smoothing kernel for uniform smoothing
K = ones(n,n,n) ./ n^3;
% Apply convolution kernel
Cube = convn(Cube, K ,'same');
% Take 1 voxel every n in each direction
Cube = Cube(1:n:end, 1:n:end, 1:n:end);

% Update full MRI structure
if isstruct(sMri)
    sMri.Cube = Cube;
    % Update voxel size
%     fscale = oldSize ./ size(sMri.Cube);
    fscale = [n n n];
    sMri.Voxsize = fscale .* sMri.Voxsize;
    Tdownsample = diag([fscale, 1]);
    % Update vox2mri transformation in Brainstorm structure
    if isfield(sMri, 'InitTransf') && ~isempty(sMri.InitTransf) && any(ismember(sMri.InitTransf(:,1), 'vox2ras'))
        iTransf = find(strcmpi(sMri.InitTransf(:,1), 'vox2ras'));
        sMri.InitTransf{iTransf(1),2} = Tdownsample * sMri.InitTransf{iTransf(1),2};
    end
    % Update vox2mri transformation in nifti header
    if isfield(sMri, 'Header') && isfield(sMri.Header, 'nifti') && all(isfield(sMri.Header.nifti, {'vox2ras', 'srow_x', 'srow_y', 'srow_z'}))
        sMri.Header.nifti.vox2ras = Tdownsample * sMri.Header.nifti.vox2ras;
        sMri.Header.nifti.vox2ras = Tdownsample(1,1) * sMri.Header.nifti.srow_x;
        sMri.Header.nifti.vox2ras = Tdownsample(2,2) * sMri.Header.nifti.srow_y;
        sMri.Header.nifti.vox2ras = Tdownsample(3,3) * sMri.Header.nifti.srow_z;
    end
    % Update the fiducial coordinates (used as the origin of the volume)
    if isfield(sMri, 'SCS') 
        for fidname = {'NAS','LPA','RPA','Origin'}
            if isfield(sMri.SCS, fidname{1}) && (length(sMri.SCS.(fidname{1})) == 3)
                sMri.SCS.(fidname{1})(1) = sMri.SCS.(fidname{1})(1) ./ fscale(1);
                sMri.SCS.(fidname{1})(2) = sMri.SCS.(fidname{1})(2) ./ fscale(2);
                sMri.SCS.(fidname{1})(3) = sMri.SCS.(fidname{1})(3) ./ fscale(3);
            end
        end
        if isfield(sMri.SCS, 'T') && (length(sMri.SCS.T) == 3)
            sMri.SCS.T(1) = sMri.SCS.T(1) ./ fscale(1);
            sMri.SCS.T(2) = sMri.SCS.T(2) ./ fscale(2);
            sMri.SCS.T(3) = sMri.SCS.T(3) ./ fscale(3);
        end
        if isfield(sMri.SCS, 'R') && ~isempty(sMri.SCS.R)
            sMri.SCS.R = diag(1./fscale) * sMri.SCS.R;
        end
    end
    if isfield(sMri, 'NCS') 
        for fidname = {'AC','PC','IH','Origin'}
            if isfield(sMri.NCS, fidname{1}) && (length(sMri.NCS.(fidname{1})) == 3)
                sMri.NCS.(fidname{1})(1) = sMri.NCS.(fidname{1})(1) ./ fscale(1);
                sMri.NCS.(fidname{1})(2) = sMri.NCS.(fidname{1})(2) ./ fscale(2);
                sMri.NCS.(fidname{1})(3) = sMri.NCS.(fidname{1})(3) ./ fscale(3);
            end
        end
        if isfield(sMri.NCS, 'T') && (length(sMri.NCS.T) == 3)
            sMri.NCS.T(1) = sMri.NCS.T(1) ./ fscale(1);
            sMri.NCS.T(2) = sMri.NCS.T(2) ./ fscale(2);
            sMri.NCS.T(3) = sMri.NCS.T(3) ./ fscale(3);
        end
        if isfield(sMri.NCS, 'R') && ~isempty(sMri.NCS.R)
            sMri.NCS.R = diag(1./fscale) * sMri.NCS.R;
        end
    end
else
    sMri = Cube;
end




