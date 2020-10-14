function varargout = process_simulate_dipoles( varargin )
% PROCESS_SIMULATE_DIPOLES: Simulate recordings based on a list of dipoles.
%
% USAGE:  OutputFiles = process_simulate_dipoles('Run', sProcess, sInputA)
 
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
% Authors: Francois Tadel, 2020

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Simulate recordings from dipoles';
    sProcess.Category    = 'File';
    sProcess.SubGroup    = 'Simulate'; 
    sProcess.Index       = 920;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Simulations#Single_dipoles';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'matrix'};
    sProcess.OutputTypes = {'data'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;

    % Notice inputs
    sProcess.options.label1.Comment = ['<FONT COLOR="#777777">&nbsp;- N signals: defined in the input files<BR>' ...
                                       '&nbsp;- N dipoles: defined below, one dipole per line (millimeters)</FONT>'];
    sProcess.options.label1.Type    = 'label';
    sProcess.options.label1.Group   = 'input';
    % === DIPOLES
    sProcess.options.dipoles.Comment = '<FONT COLOR="#777777"><I>posX, posY, posZ, orientX, orientY, orientZ</I></FONT>';
    sProcess.options.dipoles.Type    = 'textarea';
    sProcess.options.dipoles.Value   = ['-48, -2, -4, 1, 0, -1' 10 '48, -2, -4, 1, 0, -1'];
    sProcess.options.dipoles.Group   = 'input';
    % === COORDINATE SYSTEM
    sProcess.options.cs.Comment = {'SCS', 'MRI', 'World', 'MNI', 'Coordinate system: '; 'scs', 'mri', 'world', 'mni', ''};
    sProcess.options.cs.Type    = 'radio_linelabel';
    sProcess.options.cs.Value   = 'mni';
    sProcess.options.cs.Group   = 'input';
    % === FORWARD MODEL
    % Option: MEG headmodel
    sProcess.options.label2.Comment = '<B>Forward modeling methods</B>:';
    sProcess.options.label2.Type    = 'label';
    sProcess.options.meg.Comment = '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;MEG method:';
    sProcess.options.meg.Type    = 'combobox_label';
    sProcess.options.meg.Value   = {'os_meg', {'<none>', 'Single sphere', 'Overlapping spheres', 'OpenMEEG BEM', 'DUNEuro FEM'; '', 'meg_sphere', 'os_meg', 'openmeeg', 'duneuro'}};
    % Option: EEG headmodel
    sProcess.options.eeg.Comment = '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;EEG method:';
    sProcess.options.eeg.Type    = 'combobox_label';
    sProcess.options.eeg.Value   = {'openmeeg', {'<none>', '3-shell sphere', 'OpenMEEG BEM', 'DUNEuro FEM'; '', 'eeg_3sphereberg', 'openmeeg', 'duneuro'}};
    % Option: ECOG headmodel
    sProcess.options.ecog.Comment = '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;ECOG method:';
    sProcess.options.ecog.Type    = 'combobox_label';
    sProcess.options.ecog.Value   = {'', {'<none>', 'OpenMEEG BEM'; '', 'openmeeg'}};
    % Option: SEEG headmodel
    sProcess.options.seeg.Comment = '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;SEEG method:';
    sProcess.options.seeg.Type    = 'combobox_label';
    sProcess.options.seeg.Value   = {'', {'<none>', 'OpenMEEG BEM'; '', 'openmeeg'}};
    % Options: OpenMEEG Options
    sProcess.options.openmeeg.Comment = {'panel_openmeeg', '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;OpenMEEG options: '};
    sProcess.options.openmeeg.Type    = 'editpref';
    sProcess.options.openmeeg.Value   = bst_get('OpenMEEGOptions');
    % Options: DUNEuro Options
    sProcess.options.duneuro.Comment = {'panel_duneuro', '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;DUNEuro options: '};
    sProcess.options.duneuro.Type    = 'editpref';
    sProcess.options.duneuro.Value   = bst_get('DuneuroOptions');
    
    % === ADD NOISE
    sProcess.options.label3.Comment = '<B>Simulated signals</B>:';
    sProcess.options.label3.Type    = 'label';
    sProcess.options.isnoise.Comment = 'Add noise';
    sProcess.options.isnoise.Type    = 'checkbox';
    sProcess.options.isnoise.Value   = 0;
    sProcess.options.isnoise.Controller = 'Noise';
    % === LEVEL OF NOISE (SNR1)
    sProcess.options.noise1.Comment = '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Level of source noise (SNR1):';
    sProcess.options.noise1.Type    = 'value';
    sProcess.options.noise1.Value   = {0, '', 2};
    sProcess.options.noise1.Class   = 'Noise';
    % === LEVEL OF SENSOR NOISE (SNR2)
    sProcess.options.noise2.Comment = '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Level of sensor noise (SNR2):';
    sProcess.options.noise2.Type    = 'value';
    sProcess.options.noise2.Value   = {0, '', 2};
    sProcess.options.noise2.Class   = 'Noise';
    % === SAVE DIPOLES
    sProcess.options.savedip.Comment = 'Save dipoles in database';
    sProcess.options.savedip.Type    = 'checkbox';
    sProcess.options.savedip.Value   = 1;
    sProcess.options.savedip.Group   = 'output';
    % === SAVE DATA 
    sProcess.options.savedata.Comment = 'Save recordings';
    sProcess.options.savedata.Type    = 'checkbox';
    sProcess.options.savedata.Value   = 1;
    sProcess.options.savedata.Hidden  = 1;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInput) %#ok<DEFNU>
    OutputFiles = {};
    % Get dipoles
    try
        dip = eval(['[', sProcess.options.dipoles.Value, ']']);
    catch
        dip = [];
    end
    if (size(dip,2) ~= 6)
        bst_report('Error', sProcess, [], 'Invalid dipoles definition. The text box must define a Nx6 matrix.');
        return;
    end
    % Convert millimeters => meters
    sMethod.GridLoc = dip(:,1:3) ./ 1000;
    sMethod.GridOrient = dip(:,4:6) ./ 1000;
    % Coordinate system for the dipoles
    cs = sProcess.options.cs.Value;
    % Get forward model options
    sMethod.MEGMethod = sProcess.options.meg.Value{1};
    sMethod.EEGMethod = sProcess.options.eeg.Value{1};
    sMethod.ECOGMethod = sProcess.options.ecog.Value{1};
    sMethod.SEEGMethod = sProcess.options.seeg.Value{1};
    % OpenMEEG options
    isOpenMEEG = ismember('openmeeg', {sMethod.MEGMethod, sMethod.EEGMethod, sMethod.ECOGMethod, sMethod.SEEGMethod});
    if isOpenMEEG
        sMethod = struct_copy_fields(sMethod, sProcess.options.openmeeg.Value, 1);
        bst_set('OpenMEEGOptions', sProcess.options.openmeeg.Value);
    end
    % DUNEuro options
    isDuneuro = ismember('duneuro', {sMethod.MEGMethod, sMethod.EEGMethod, sMethod.ECOGMethod, sMethod.SEEGMethod});
    if isDuneuro
        sMethod = struct_copy_fields(sMethod, sProcess.options.duneuro.Value, 1);
        bst_set('DuneuroOptions', sProcess.options.duneuro.Value);
    end
    % Get other options
    SaveDipoles = sProcess.options.savedip.Value;
    SaveData = sProcess.options.savedata.Value;
    
    % === LOAD CHANNEL FILE ===
    % Get condition
    sStudy = bst_get('Study', sInput.iStudy);
    % Get channel file
    [sChannel, iStudyChannel] = bst_get('ChannelForStudy', sInput.iStudy);
    if isempty(sChannel)
        bst_report('Error', sProcess, [], ['No channel file available.' 10 'Please import a channel file in this study before running simulations.']);
        return;
    end

    % === CONVERT COORDINATES ===
    switch (cs)
        case 'scs'
            % No conversion to perform
        case {'mri', 'world', 'mni'}
            % Get subject
            sSubject = bst_get('Subject', sStudy.BrainStormSubject);
            if isempty(sSubject.Anatomy) || isempty(sSubject.iAnatomy)
                bst_report('Error', sProcess, [], 'No anatomy available for this subject.');
                return;
            end
            % Load MRI
            sMri = in_mri_bst(sSubject.Anatomy(sSubject.iAnatomy).FileName);
            % Convert dipoles to SCS coordinates
            [sMethod.GridLoc, Transf] = cs_convert(sMri, cs, 'scs', sMethod.GridLoc);
            sMethod.GridOrient = (Transf(1:3,1:3) * sMethod.GridOrient')';
    end

    % === COMPUTE FORWARD MODEL ===
    % Other options
    sMethod.HeadModelType = 'surface';
    sMethod.Interactive = 0;
    sMethod.SaveFile = 0;
    % Call head modeler
    [HeadModelMat, errMessage] = panel_headmodel('ComputeHeadModel', iStudyChannel, sMethod);
    % Report errors
    if isempty(HeadModelMat) && ~isempty(errMessage)
        bst_report('Error', sProcess, sInput, errMessage);
        return;
    elseif ~isempty(errMessage)
        bst_report('Warning', sProcess, sInput, errMessage);
    end
    
    % === CALL PROCESS "SIMULATE RECORDINGS" ===
    % Prepare process "Simulate recordings from scouts" with defined head model
    sProcess.options.savesources.Value = 0;
    sProcess.options.headmodel.Value = HeadModelMat{1};
    % Call process
    OutputFiles = process_simulate_recordings('Run', sProcess, sInput);

    % ===== SAVE DIPOLES FILE =====
    if SaveDipoles
        % Read input file
        sMatrix = in_bst_matrix(sInput.FileName, 'Description', 'Comment');
        % Create a new source file structure
        DipoleMat = db_template('dipolemat');
        DipoleMat.Comment     = sMatrix.Comment;
        DipoleMat.Time        = 0;
        DipoleMat.DipoleNames = sMatrix.Description;
        for iDip = 1:size(sMethod.GridLoc,1)
            DipoleMat.Dipole(iDip).Index     = 1;
            DipoleMat.Dipole(iDip).Time      = 0;
            DipoleMat.Dipole(iDip).Origin    = [0 0 0];
            DipoleMat.Dipole(iDip).Loc       = sMethod.GridLoc(iDip,:)';
            DipoleMat.Dipole(iDip).Amplitude = sMethod.GridOrient(iDip,:)';
            DipoleMat.Dipole(iDip).Goodness  = 1;
            DipoleMat.Dipole(iDip).Errors    = 0;
        end
        if SaveData
            DipoleMat.DataFile = file_short(OutputFiles{1});
        else
            DipoleMat.DataFile = [];
        end
        % Add history entry
        DipoleMat = bst_history('add', DipoleMat, 'simulate', ['Simulated from ' sProcess.options.cs.Value 'coordinates: ' strrep(sProcess.options.dipoles.Value, char(10), '; ')]);

        % Create output filename
        [fPath, fName] = bst_fileparts(file_fullpath(sInput.FileName));
        DipoleFile = file_unique(bst_fullfile(fPath, ['dipoles_' strrep(fName, 'matrix_', ''), '.mat']));
        % Save new file in Brainstorm format
        bst_save(DipoleFile, DipoleMat);

        % === UPDATE DATABASE ===
        % Create structure
        BstDipolesMat = db_template('Dipoles');
        BstDipolesMat.FileName = file_short(DipoleFile);
        BstDipolesMat.Comment  = DipoleMat.Comment;
        BstDipolesMat.DataFile = DipoleMat.DataFile;
        % Add to study
        sStudy = bst_get('Study', sInput.iStudy);
        iDipole = length(sStudy.Dipoles) + 1;
        sStudy.Dipoles(iDipole) = BstDipolesMat;
        % Save study
        bst_set('Study', sInput.iStudy, sStudy);
        % Update tree
        panel_protocols('UpdateNode', 'Study', sInput.iStudy);
        % Save database
        db_save();
        % Return as output file if not saving data
        if ~SaveData
            OutputFiles = {DipoleFile};
        end
    end
end



%% ===== GET NOISE SIGNALS =====
% GET_NOISE_SIGNALS: Generates noise signals from a noise covariance matrix
%
% INPUT:
%    - COV: Noise covariance matrix (M x M)
%    - Nsamples: Number of time points (length of noise signals)
% OUTPUT:
%    - xn: noise signals (M x Nsamples)
%
% DESCRIPTION: 
%     White noise covariance:
%     CXw = Xw * Xw' = Id
%     Gaussian white uncorrelated noise (randn)
%     Xw: (Nchannels x t)
% 
%     We have the following noise covariance matrix: C, and we decompose it into eigenvalues and eigenvectors:
%     C = v * D * v' = v * D^(1/2) * D^(1/2) * v'
%     Since C is symmetric, D is positive and D^(1/2) = D.^(1/2) (element by element)
% 
%     Therefore we define the noise signal we wanted to add as:
%     X = v * D^(1/2) * Xw
%     And obtain its covariance matrix as:
%     CX = Xw * Xw' = v * D^(1/2) * Xw * (v * D^(1/2) * Xw)' = v * D^(1/2) * Xw * XwT * D^(1/2)' * v'
%        = v * D^(1/2) * CXw * D^(1/2)' * v' = v * D^(1/2) * D^(1/2)' * v' = v * D * v' = C  
%     => Cov = xn * xn’ ./( Nsamples- 1)
%
% Author: Guiomar Niso, 2014
%
function xn = get_noise_signals(COV, Nsamples)
    [V,D] = eig(COV);

    % xn = (1/SNR) * V * D.^(1/2) * randn(size(COV,1),Nsamples);
    xn = V * D.^(1/2) * randn(size(COV,1),Nsamples);

    %%%%%%
    % Example:
    % SNR = 0.3;
    % Nsamples = 500;
    % xn = get_noise_signals (n.NoiseCov, Nsamples);
    % xnn = xn./max(max(xn));
    % xns = xnn.*max(max(s.F));
    % sn = s.F + SNR*xns;
    % s.F=sn;

    % figure(1); imagesc(n.NoiseCov); colorbar;
    % figure(2); imagesc(xn*xn' ./ (size(xn,2) - 1)); colorbar;
    % figure(3); imagesc(cov(xn)); colorbar;
    % See also noise extracted from recordings
end
