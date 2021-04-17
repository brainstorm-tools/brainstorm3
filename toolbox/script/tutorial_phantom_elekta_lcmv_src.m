function tutorial_phantom_elekta_lcmv_src(sAvgKojak,DipNdx,InverseMethod,SUBARRAY,DipTrueFile)
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
% Authors: John Mosher, 2016

% Runs the GLS inverse procedure for the average data identified by the
% DipNdx, and compares them to the true locations
% Time is specifically at 60 ms into the epoch, the peak at 10 ms sampling

switch InverseMethod
    case 'lcmv'
        Comment = sprintf('PNAI: %s',SUBARRAY);
    case 'gls'
        Comment = sprintf('Dipoles: %s',SUBARRAY);
end

%% Process: Compute sources [2018]
sAvgSrcKojak = bst_process('CallProcess', 'process_inverse_2018', sAvgKojak(DipNdx), [], ...
    'output',  1, ...  % Kernel only: shared
    'inverse', struct(...
    'Comment', Comment, ...
    'InverseMethod', InverseMethod, ...
    'InverseMeasure', 'performance', ...
    'SourceOrient', {{'free'}}, ...
    'Loose', 0.2, ...
    'UseDepth', 0, ...
    'WeightExp', 0.5, ...
    'WeightLimit', 10, ...
    'NoiseMethod', 'none', ...
    'NoiseReg', 0.1, ...
    'SnrMethod', 'rms', ...
    'SnrRms', 0, ...
    'SnrFixed', 3, ...
    'ComputeKernel', 1, ...
    'DataTypes', {{SUBARRAY}}));

%%
% ===== DIPOLE SCANNING =====
% Process: Dipole scanning
sDipScan = bst_process('CallProcess', 'process_dipole_scanning', sAvgSrcKojak, [], ...
    'timewindow', [0.06, 0.06], ...
    'scouts',     {});

%%
% Merge all 32 dipoles together
DipMergeFile = dipoles_merge({sDipScan.FileName});

% Flip orientations
dip = load(DipMergeFile);

for i = 1:length(DipNdx),
    dip.Dipole(i).Amplitude = dip.Dipole(i).Amplitude * sign(dip.Dipole(i).Amplitude(3));
end
dip.Comment = [dip.Comment ' | flipped'];
DipFlipFile = db_add(sDipScan(1).iStudy, dip);

%%
% Merge with true locations
DipAllFile = dipoles_merge({DipTrueFile, DipFlipFile});
% visualize on the MRI 3D
view_dipoles(DipAllFile, 'Mri3D');
view(3)

%%
% ===== REPORT =====
% Get the True Dipole Locations
TrueDipoles = load(file_fullpath(DipTrueFile));
true_loc    = [TrueDipoles.Dipole.Loc];
true_orient = [TrueDipoles.Dipole.Amplitude];

% Display stats
fprintf('\n Dipole Statistics and Error Summary\n\n')
fprintf(' Dipole      Loc (mm)      Amp (nA-m)  Gof     Perf       Chi2     RChi2  Error: (mm)  (Degrees)\n')
fprintf('---------------------------------------------------------------------------------------------\n')
for i = 1:length(DipNdx),
    temp_diff = dip.Dipole(i).Loc-true_loc(:,DipNdx(i));
    Amp    = dip.Dipole(i).Amplitude;
    nAmp   = norm(Amp);
    Orient = Amp / nAmp;
    
    fprintf('  %02.0f - [%5.1f %5.1f %5.1f]   %5.1f   %5.1f%%    %5.1f  %5.0f (%3.0f)   %.2f    (%5.1f)    (%5.1f)\n',...
        DipNdx(i), dip.Dipole(i).Loc*1000, norm(dip.Dipole(i).Amplitude)*1e9, ...
        dip.Dipole(i).Goodness*100, dip.Dipole(i).Perform, ...
        dip.Dipole(i).Khi2, dip.Dipole(i).DOF, dip.Dipole(i).Khi2/dip.Dipole(i).DOF, ...
        norm(temp_diff)*1000, (subspace(Orient,true_orient(:,DipNdx(i))))*180/pi),
end

% Compare errors, but dependent on order being correct
fprintf('\n Detailed Location Errors from True\n\n')
fprintf(' Dipole      Loc (mm)                True (mm)           Diff [x y z]     Error (mm)\n')
fprintf('------------------------------------------------------------------------------\n')
for i = 1:length(DipNdx)
    temp_diff = dip.Dipole(i).Loc-true_loc(:,DipNdx(i));
    fprintf('  %02.0f - [%5.1f %5.1f %5.1f] vs. [%5.1f %5.1f %5.1f] = [%5.1f %5.1f %5.1f]   (%5.1f)\n',...
        DipNdx(i), dip.Dipole(i).Loc*1000, true_loc(:,DipNdx(i))*1000, temp_diff*1000, norm(temp_diff)*1000);
end

% Orientation errors
fprintf('\n Detailed Orientation Errors from True\n\n')
fprintf(' Dipole  Amp (nA-m)      [X Y Z]               TRUE [X Y Z]      Error (Degrees)\n')
fprintf('------------------------------------------------------------------------\n')
for i = 1:length(DipNdx)
    Amp    = dip.Dipole(i).Amplitude;
    nAmp   = norm(Amp);
    Orient = Amp / nAmp;
    fprintf('  %02.0f -    (%5.1f)  [%5.2f %5.2f %5.2f] vs. [%5.2f %5.2f %5.2f] = (%5.1f )\n',...
        DipNdx(i), nAmp*1e9, Orient, true_orient(:,DipNdx(i)), (subspace(Orient,true_orient(:,DipNdx(i))))*180/pi);
end


