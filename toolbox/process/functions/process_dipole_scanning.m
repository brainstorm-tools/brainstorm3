function varargout = process_dipole_scanning( varargin )
% PROCESS_DIPOLE_SCANNING: Generates a brainstorm dipole file from the GLS and GLS-P inverse solutions.

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
% Authors: Elizabeth Bock, John C. Mosher, Francois Tadel, 2013-2019

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Dipole scanning';
    sProcess.Category    = 'File';
    sProcess.SubGroup    = 'Sources';
    sProcess.Index       = 327;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/TutDipScan';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'results'};
    sProcess.OutputTypes = {'dipoles'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Definition of the options
     % === Time window
    sProcess.options.timewindow.Comment = 'Time window:';
    sProcess.options.timewindow.Type    = 'timewindow';
    sProcess.options.timewindow.Value   = [];
%     % === fit frequency
%     sProcess.options.downsample.Comment = 'Time between dipoles: ';
%     sProcess.options.downsample.Type    = 'value';
%     sProcess.options.downsample.Value   = {0.000, 'ms', []};
    % === Separator
    sProcess.options.sep2.Type = 'separator';
    sProcess.options.sep2.Comment = ' ';
    % === CLUSTERS
    sProcess.options.scouts.Comment = 'Limit scanning to selected scouts';
    sProcess.options.scouts.Type    = 'scout_confirm';
    sProcess.options.scouts.Value   = {};
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInput) %#ok<DEFNU>
    OutputFiles = {};
    % === Get options
     % Time window to process
     %FitPeriod  = sProcess.options.downsample.Value{1};
    TimeWindow = sProcess.options.timewindow.Value{1};
    FitPeriod  = 0;
    AtlasList  = sProcess.options.scouts.Value;

    % === Get the sources
    % Read the source file
    sResultP = in_bst_results(sInput.FileName, 0);
    % Only accept dipole modeling in input
    switch sResultP.Function
        case {'gls_p','glsp','lcmvp'}
            % do nothing, valid
        otherwise
            bst_report('Error', sProcess, [], 'Dipole scanning is only available for the "Dipole modeling" and "LCMV" options (GLS-performance in the old interface).');
            return;
    end
    % Get the scouts structures
    if ~isempty(AtlasList)
        [sScouts, AtlasNames, sSurf] = process_extract_scout('GetScoutsInfo', sProcess, sInput, sResultP.SurfaceFile, AtlasList);
    else
        sScouts = [];
    end
    
    
    % === Get the results
    if isempty(sResultP.DataFile)
        DataMatP.Time = sResultP.Time;
        DataMatP.F = [];
        DataMatP.Comment = sResultP.Comment;
        % DataMatP.nAvg = sResultP.nAvg;
        DataMatP.Leff = sResultP.Leff;
    else
        DataMatP = in_bst_data(sResultP.DataFile);
    end
    
    if isempty(sResultP.ImageGridAmp)
        % this can be massive, we should find a more iterative way
        % For now (March 2016), assume being only used for short data
        % sequences. (Mosher April 2016)
        sResultP.ImageGridAmp = sResultP.ImagingKernel * DataMatP.F(sResultP.GoodChannel,:);
    end
    

    % The function in_bst_results has already scaled the ImagingKernel to account for
    % data that has been averaged, so that the noise covariance scaling is correct.
    % So ImageGridAmp should also be correct.
    % But we need to calculate the possible Factor here for any other
    % manipulation of the data, as needed below.
    Factor = sqrt(DataMatP.Leff / sResultP.Leff); % is unity if both equal.
    if Factor ~= 1
        fprintf('BST Dipole Scanning> Need additional factor of %.2f (sqrt of %.1f) to account for average.\n',Factor, Factor^2);
    end
    
    % === Get the time
    if ~isempty(TimeWindow)
        SamplesBounds = bst_closest(TimeWindow, DataMatP.Time);
    else
        SamplesBounds = [1, size(sResultP.ImageGridAmp,2)];
    end
    timeVector = DataMatP.Time(SamplesBounds(1):SamplesBounds(2));
    
    % The "performance" image matrix
    Perf = sResultP.ImageGridAmp(:,SamplesBounds(1):SamplesBounds(2));
    % For constrained or mixed models this will flatten to norm
    sResultPFlat = process_source_flat('Compute',sResultP, 'rms');
    Pscan = sResultPFlat.ImageGridAmp(:,SamplesBounds(1):SamplesBounds(2));
    
    % === Find the index of 'best fit' at every time point
    % Get the selected scouts
    if ~isempty(sScouts)
        scoutVerts = [];
        for iScout = 1:length(sScouts)
            scoutVerts = [scoutVerts sScouts(iScout).Vertices];
        end
        [mag,ind] = max(Pscan(scoutVerts,:));
        maxInd = scoutVerts(ind);
    else
        % don't use scouts, use all vertices
        [mag,maxInd] = max(Pscan,[],1);
    end
    
    % === Prepare a mask for downsampling the number of dipoles to save
    NumDipoles = size(Perf,2);
    if FitPeriod > 0
        tTotal = timeVector(end) - timeVector(1);
        nNewDipoles = tTotal/FitPeriod;
        dsFactor = round(NumDipoles/nNewDipoles);
    else
        dsFactor = 1;
    end
    temp = zeros(1,dsFactor);
    temp(1) = 1;
    dsMask = repmat(temp, 1, floor(NumDipoles/dsFactor));
    dsMask = logical([dsMask zeros(1,NumDipoles-length(dsMask))]);
    % downsample 
    dsTimeVector = timeVector(dsMask);
    dsMaxInd = maxInd(dsMask);

    % So we have an index to each dipole location that has maximum
    % performance that we seek. Now find orientation and dipole amplitude
    
    % Get headmodel parameters
    sHeadModel = bst_get('HeadModelForStudy', sInput.iStudy);
    if isempty(sHeadModel)
        HeadModelFile = sResultP.HeadModelFile; 
        if isempty(HeadModelFile)
            error('No headmodel available for this result file.');
        end
    else
        HeadModelFile = sHeadModel.FileName;
    end
    
    % HeadModelMat = in_bst_headmodel(HeadModelFile, 0, 'Gain', 'GridLoc', 'GridOrient');
    % Don't need large gain matrix
    HeadModelMat = in_bst_headmodel(HeadModelFile, 0, 'GridLoc', 'GridOrient');
    
    % === find the orientations
    switch (sResultP.nComponents)
        case 0  % MIXED HEAD MODEL
 %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%   
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%         
error('Not supported yet.');
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%  
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%   
            %fullPerf = zeros(3, size(Perf,1), size(Perf,2));
            nTime = size(Perf,2);
            fullPerf = {};
            % Loop on all the regions
            for iScout = 1:length(sResultP.GridAtlas.Scouts)
                % Get the grid indices for this scouts
                iGrid = sResultP.GridAtlas.Scouts(iScout).GridRows;
                % If no vertices to read from this region: skip
                if isempty(iGrid)
                    continue;
                end
                % Get correpsonding row indices based on the type of region (constrained or unconstrained)
                switch (sResultP.GridAtlas.Scouts(iScout).Region(3))
                    case 'C'
                        fullPerf{end+1} = repmat(sResultP.GridOrient(iGrid,:)', 1, 1, nTime);
                    case {'U','L'}
                        % Convert from indices in GridLoc to indices in the source matrix
                        iSourceRows = bst_convert_indices(iGrid, sResultP.nComponents, sResultP.GridAtlas, 0);
                        fullPerf{end+1} = reshape(Perf(iSourceRows,:), 3, [], size(Perf,2));
                    otherwise
                        error(['Invalid region "' sResultP.GridAtlas.Scouts(iScout).Region '"']);
                end
            end
            % Concatenate the blocks
            fullPerf = cat(2, fullPerf{:});
            % Dipole orientation = amplitude in the three orientations
            orient = zeros(size(fullPerf,1),length(dsMaxInd)); % allocate
            for jj = 1:length(dsMaxInd)
                orient(:,jj) = fullPerf(:,dsMaxInd(jj),jj);
            end
        case 1
            % use the headmodel orientations
            kk = sResultP.nComponents; % notation convenience in below loop
            fullPerf = reshape(Perf,kk,[],size(Perf,2));
            orient = HeadModelMat.GridOrient(dsMaxInd,:)'; % simply the grid orient
            
            % now calculate the amplitude and embed in the orientation.
            % xhat = orientation * pinv(A * orientation) times data
            % A and data whitened and decomposed already, a rank one model
            for jj = 1:length(dsMaxInd)               
                temp_ForwardModel = sResultP.SourceDecompSa(1,dsMaxInd(jj)); % scale factor from SVD
                temp_ForwardModel = temp_ForwardModel * Factor; % need to account for average vs epoched data.
                % Now pseudo invert this to get the scalar amplitude of source.
                % Note that fullPerf (the Perf value) already has the left singular
                % vectors.
                temp_estimate = fullPerf(1,dsMaxInd(jj),jj)/temp_ForwardModel;
                % replace unit orient with this orientation times the amplitude
                orient(:,jj) = temp_estimate * orient(:,jj);
            end
        case 2
            error('Not supported.');
        case 3
            % calculate the dipole orientations
            % first extract the calculation from the kernel, which is
            % performance:
            kk = sResultP.nComponents; % notation convenience in below loop
            fullPerf = reshape(Perf,kk,[],size(Perf,2));
            % Now calculate the optimal orientation from the performance
            orient = zeros(size(fullPerf,1),length(dsMaxInd)); % allocate
            for jj = 1:length(dsMaxInd)
                orient(:,jj) = fullPerf(:,dsMaxInd(jj),jj);
                % this is the raw orientation ("p") vector from the
                % performance measure. Since it is a single time slice (for
                % now April 2016), then no need to SVD. To get the optimal
                % orientation, we need to multiply it by the corresponding
                % head model decomposition components
                % Note, scale factor not important here since we normalize.
                orient(:,jj) = sResultP.SourceDecompVa(:,((1-kk):0)+(dsMaxInd(jj)*kk)) * diag(sResultP.SourceDecompSa(:,dsMaxInd(jj))) * orient(:,jj);
                orient(:,jj) = orient(:,jj) / norm(orient(:,jj)); % unit norm
                
                % with the orientation optimized, now calculate the
                % amplitude and embed in the orientation.
                % xhat = orientation * pinv(A * orientation) times data
                % A and data whitened and decomposed already, a rank three
                % model
                temp_ForwardModel = diag(sResultP.SourceDecompSa(:,dsMaxInd(jj))) * sResultP.SourceDecompVa(:,((1-kk):0)+(dsMaxInd(jj)*kk))'*orient(:,jj); % particular orientation
                temp_ForwardModel = temp_ForwardModel * Factor; % need to account for average vs epoched data.
                % Now pseudo invert this to get the scalar amplitude of source.
                % Note that fullPerf (the Perf value) already has the left singular
                % vectors.
                % pseudo invert temp_ForwardModel, a 3 x 1, by simply
                % transposing and dividing by the norm^2
                temp_estimate = (temp_ForwardModel'/ (temp_ForwardModel'*temp_ForwardModel)) * fullPerf(:,dsMaxInd(jj),jj);
                % replace unit orient with this orientation times the amplitude
                orient(:,jj) = temp_estimate * orient(:,jj);
                
            end
    end
    
%     % Dipole Amplitude, embed in orient. Use "fullPerf" generated above
%     %TBD: can be simplified from calculation given here, but this is direct
%     for jj = 1:length(dsMaxInd),
%         % form the source model, without the leading left singular vectors
%         kk = sResultP.nComponents; % notation convenience below
%         temp_ForwardModel = diag(sResultP.SourceDecompSa(:,dsMaxInd(jj))) * sResultP.SourceDecompVa(:,((1-kk):0)+(dsMaxInd(jj)*kk))'*orient(:,jj); % particular orientation
%         temp_ForwardModel = temp_ForwardModel * Factor; % need to account for average vs epoched data.
%         % Now pseudo invert this to get the scalar amplitude of source.
%         % Note that fullPerf (the Perf value) already has the left singular
%         % vectors.
%         temp_estimate = pinv(temp_ForwardModel) * fullPerf(:,dsMaxInd(jj),jj);
%         % replace unit orient with this orientation times the amplitude
%         orient(:,jj) = temp_estimate * orient(:,jj);
%     end
%     
    % === Goodness of fit
    % square the performance at every source, therefore resulting in a
    % scalar squared performance value at every dipolar source
    %P2 = sum(reshape(abs(Perf).^2,sResultP.nComponents,[]),1);
    %P2 = reshape(P2,[],size(Perf,2));
    P2 = Pscan .^ 2;

    % get the squared norm of the whitened data, account for averaged data
    % factor as well.
    % Use the correct whitener, depending on lcmv vs gls
    switch sResultP.Options.InverseMethod        
        case 'lcmv'
            wd2 = sum(abs(Factor * sResultP.DataWhitener * DataMatP.F(sResultP.GoodChannel,SamplesBounds(1):SamplesBounds(2))).^2,1);
        otherwise
            wd2 = sum(abs(Factor * sResultP.Whitener * DataMatP.F(sResultP.GoodChannel,SamplesBounds(1):SamplesBounds(2))).^2,1);
    end
    
    % the goodness of fit is now calculated by dividing the norm into each
    % performance value
    gof = P2 * diag(1./wd2);

    % === Chi-square
    % the chi square is the difference of the norm and the performance
    % resulting in the error for every source at every time point
    ChiSquare = repmat(wd2,size(P2,1),1) - P2;

    % The reduced chi-square is found by dividing by the degrees of freedom in
    % the error, which (for now) is simply a scalar, since we assume all
    % sources have the same degrees of freedom. Thus ROI modeling will require
    % that all ROIs have the same DOF. 
    DOF = size(sResultP.ImagingKernel,2) - sResultP.nComponents;

    % downsample
    dsChiSquare = ChiSquare(:,dsMask);
    dsGOF = gof(:,dsMask);
    dsP = Pscan(:,dsMask);
    
    NumDipoles = length(dsMaxInd);
    
    %% === CREATE OUTPUT STRUCTURE ===
    bst_progress('start', 'Dipole File', 'Saving result...');
    % Get output study
    [sStudy, iStudy] = bst_get('Study', sInput.iStudy);
    % Comment: forced in the options
    if isfield(sProcess.options, 'Comment') && isfield(sProcess.options.Comment, 'Value') && ~isempty(sProcess.options.Comment.Value)
        Comment = sProcess.options.Comment.Value;
    % Comment: process default
    else
        Comment = [DataMatP.Comment ' | dipole-scan'];
    end
    % Get base filename
    [fPath, fBase, fExt] = bst_fileparts(sInput.FileName);
    % Create base structure
    DipolesMat = db_template('dipolemat');
    DipolesMat.Comment = Comment;
    DipolesMat.Time    = unique(dsTimeVector);
    
    % Fill structure    
    for i = 1:NumDipoles
        DipolesMat.Dipole(i).Index          = 1;
        DipolesMat.Dipole(i).Time           = dsTimeVector(i);
        DipolesMat.Dipole(i).Origin         = [0 0 0];
        DipolesMat.Dipole(i).Loc            = HeadModelMat.GridLoc(dsMaxInd(i),:)';
        DipolesMat.Dipole(i).Amplitude      = orient(:,i);
        DipolesMat.Dipole(i).Errors         = 0;
        DipolesMat.Dipole(i).Noise          = [];
        DipolesMat.Dipole(i).SingleError    = [];
        DipolesMat.Dipole(i).ErrorMatrix    = [];
        DipolesMat.Dipole(i).ConfVol        = [];
        DipolesMat.Dipole(i).Probability    = [];
        DipolesMat.Dipole(i).NoiseEstimate  = [];
        DipolesMat.Dipole(i).Perform        = dsP(dsMaxInd(i),i);
        
        if ~isempty(dsGOF)
           DipolesMat.Dipole(i).Goodness = dsGOF(dsMaxInd(i),i);
        end
        if ~isempty(dsChiSquare)
           DipolesMat.Dipole(i).Khi2 = dsChiSquare(dsMaxInd(i),i);
        end
        if ~isempty(DOF)
           DipolesMat.Dipole(i).DOF = DOF;
        end
    end

    % Create the dipoles names list
    dipolesList = unique([DipolesMat.Dipole.Index]); %unique group names
    DipolesMat.DipoleNames = cell(1,length(dipolesList));
    k = 1; %index of names for groups with subsets
    nChanSet = 1;
    for i = 1:(length(dipolesList)/nChanSet)
        % If more than one channel subset, name the groups according to index and subset number
        if nChanSet > 1
            for j = 1:nChanSet
                DipolesMat.DipoleNames{k} = sprintf('Group #%d (%d)', dipolesList(i), j);
                DipolesMat.Subset(k) = j;
                k=k+1;
            end
        % If only one subsets, name the groups according to index
        else
            DipolesMat.DipoleNames{i} = sprintf('Group #%d', dipolesList(i));
            DipolesMat.Subset(i) = 1;
        end

    end
    DipolesMat.Subset = unique(DipolesMat.Subset);
    % Attach the new file to the input file
    DipolesMat.DataFile = sInput.FileName;
    % Add History field
    DipolesMat = bst_history('add', DipolesMat, 'scanning', ['Generated from: ' sInput.FileName]);
   
    % ===== SAVE NEW FILE =====
    % Create output filename
    ProtocolInfo = bst_get('ProtocolInfo');
    DipoleFile = bst_fullfile(ProtocolInfo.STUDIES, bst_fileparts(sStudy.FileName), 'dipoles_fit.mat');
    DipoleFile = file_unique(DipoleFile);
    % Save new file in Brainstorm format
    bst_save(DipoleFile, DipolesMat);

    % ===== UPDATE DATABASE =====
    % Create structure
    BstDipolesMat = db_template('Dipoles');
    BstDipolesMat.FileName = file_short(DipoleFile);
    BstDipolesMat.Comment  = Comment;
    BstDipolesMat.DataFile = sInput.FileName;
    % Add to study
    iDipole = length(sStudy.Dipoles) + 1;
    sStudy.Dipoles(iDipole) = BstDipolesMat;
    
    % Save study
    bst_set('Study', iStudy, sStudy);
    % Update tree
    panel_protocols('UpdateNode', 'Study', iStudy);
    % Save database
    db_save();
    % Return output file
    OutputFiles{1} = DipoleFile;
end





