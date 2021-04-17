function varargout = process_pac_comod( varargin )
% process_pac_comod: Extract Comodulogram from tPAC maps.
%
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
% Authors: Soheila Samiee, 2014 - 2017
% v 1.4 :  SS, do interpolation is added to function, June 2016
% v 1.5 :  SS, Interpolation is changed for Fa, June 2016
% v 1.5.2: SS, A bug in including multiple trials in analysis is fixed,
%              Nov. 2016
% v 1.6:   SS, Computing phase Comodulogram is added to the function, Dec. 2016
% v 1.7:   SS, change in fp direction resoultion
% v 1.8:   SS, files with different format in time and FA are ignored
% v 1.9:   SS, The phase of extracted phase has the same orientation as
%          comod phase, May 2017
% v 2.0:   SS, Change in normalizing the maps, May 2017
% v 2.1:   SS, Return to previous version for normalizing (incorrect change) - July 2017
% v 2.2:   SS, tPAC, Aug 2017
% v 3.0:   SS, Check for file format before using it for fp estimation, Sep
%          2017
% v 3.3    SS, Bug fix: check time window length (line 332)

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Extracting comodulogram from tPAC maps';
    sProcess.FileTag     = '';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = {'Frequency','Time-resolved Phase-Amplitude Coupling'};
    sProcess.Index       = 1020;
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'timefreq'};
    sProcess.OutputTypes = {'timefreq'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 0;

    % === TIME WINDOW
    sProcess.options.timewindow.Comment = 'Time:';
    sProcess.options.timewindow.Type    = 'timewindow';
    sProcess.options.timewindow.Value   = [];

    % === TIME WINDOW
    sProcess.options.windowChunck.Comment = 'If you are interested in having time-resolved comod enter the length of each (sec)/otherwise: 0';
    sProcess.options.windowChunck.Type    = 'value';
    sProcess.options.windowChunck.Value   =  {0, '', 2};

    % === The sources
    sProcess.options.label.Comment = '<B> Method </B>';
    sProcess.options.label.Type    = 'label';
    sProcess.options.analyze_type.Comment = {'All sources/channels together', 'Each source/channel separately'};
    sProcess.options.analyze_type.Type    = 'radio';
    sProcess.options.analyze_type.Value   = 1;

    % === Output type
    sProcess.options.label2.Comment = '<B> Files </B>';
    sProcess.options.label2.Type    = 'label';
    sProcess.options.output_type.Comment = {'Extract one Comodulogram from all files', 'Extract Comodulogram separately for each file'};
    sProcess.options.output_type.Type    = 'radio';
    sProcess.options.output_type.Value   = 1;

    % === Interpolation
    sProcess.options.doInterp.Comment = 'Interpolate the comodulogram (recommended)';
    sProcess.options.doInterp.Type    = 'checkbox';
    sProcess.options.doInterp.Value   = 1;
end

%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end

%% ===== RUN =====
function OutputFiles = Run(sProcess, sInput) %#ok<DEFNU>
    % Get options
    t = sProcess.options.timewindow.Value;
    anal_type = sProcess.options.analyze_type.Value;
    window_length = sProcess.options.windowChunck.Value{1};
    output_type = sProcess.options.output_type.Value;
    inputTime = t{1};
    
    doInterpolation = sProcess.options.doInterp.Value; 
    if anal_type == 1
        cat_dim = 1;
    else
        cat_dim = 5;
    end
    
    
    % Set the tag
    tag = 'CoMod';

    % Load TF file
    tPACMat = in_bst_timefreq(sInput(1).FileName, 0);
    if isempty(inputTime)
        inputTime =  tPACMat.Time([1,end]);
    end
    % Error
    if isempty(tPACMat)
        bst_report('Error', 'process_pac_comod', sInput, Messages);
        return;
    end

    PAC = [];
    extract_phasePAC = 0;
    
    if length(sInput)==1 || output_type==1

        if length(sInput)>1
            
            for iFile=1:length(sInput)
                
                % check the file format
                indices = [];
                tPACMat = in_bst_timefreq(sInput(iFile).FileName, 0);
                str = tPACMat.Comment;
                tags = {'avg';'mean';'median';'fpMap';'CoMod';'zscore'};
                for itag=1:length(tags)
                    k = strfind(str,tags{itag});
                    indices = [indices,k];
                end
                
                if isempty(inputTime)
                    inputTime =  tPACMat.Time([1,end]);
                end
                if ~isempty(indices) % ignore file because it is a processed tpac map (e.g. comod or fp_map)
                    Message = ['File#',num2str(iFile),' is ignored becauase it is not a raw tPAC file'];
                    bst_report('Warning', 'process_pac_comod', sInput, Message); 
                    
                elseif isempty(PAC)   % filling the variables based on the first file  
                    time = tPACMat.Time;
                    ind_time = (time>=inputTime(1) & time<= inputTime(2));
                    Nesting = tPACMat.sPAC.DynamicNesting(:,ind_time,:);
                    PAC = tPACMat.sPAC.DynamicPAC(:,ind_time,:);
                    if isfield(tPACMat.sPAC, 'DynamicPhase')
                        Phase_mat = tPACMat.sPAC.DynamicPhase(:,ind_time,:);
                        extract_phasePAC = 1;
                    end
                    
                else
                    tPACMat2 = in_bst_timefreq(sInput(iFile).FileName, 0);
                    % Check if time and frequency definition of the current file
                    % matches the first file
                    time = tPACMat2.Time;
                    fa = tPACMat2.sPAC.HighFreqs;
                    ind_time = (time>=inputTime(1) & time<= inputTime(2));
                    if ~isequal(fa,tPACMat.sPAC.HighFreqs)
                        Message = ['File#',num2str(iFile),' is ignored because its format does not match the first file (fA definition)'];
                        bst_report('Warning', 'process_pac_comod', sInput, Message);
                    elseif ~isequal(time(ind_time),tPACMat.Time(tPACMat.Time >= inputTime(1) & tPACMat.Time <= inputTime(2)))
                        Message = ['File#',num2str(iFile),' is ignored becauase its format does not match the first file (Time definition)'];
                        bst_report('Warning', 'process_pac_comod', sInput, Message);
                    elseif ~isequal(size(Nesting,1),size(tPACMat2.sPAC.DynamicNesting,1)) && cat_dim~=1
                        Message = ['File#',num2str(iFile),' is ignored becauase its format does not match the first file (Number of channels)'];
                        bst_report('Warning', 'process_pac_comod', sInput, Message);
                    elseif ~isequal(size(Nesting,3), size(tPACMat2.sPAC.DynamicNesting,3)) || ~isequal(size(Nesting,4), size(tPACMat2.sPAC.DynamicNesting,4))
                        Message = ['File#',num2str(iFile),' is ignored becauase its format does not match the first file (fA)'];
                        bst_report('Warning', 'process_pac_comod', sInput, Message);
                    elseif ~isequal(size(Nesting,5), size(tPACMat2.sPAC.DynamicNesting,5)) && cat_dim~=5
                        Message = ['File#',num2str(iFile),' is ignored becauase its format does not match the first file'];
                        bst_report('Warning', 'process_pac_fp_map', sInput, Message);
                    else
                        Nesting = cat(cat_dim,Nesting,tPACMat2.sPAC.DynamicNesting(:,(ind_time),:));
                        PAC = cat(cat_dim,PAC,tPACMat2.sPAC.DynamicPAC(:,(ind_time),:));
                        if extract_phasePAC
                            Phase_mat = cat(cat_dim,Phase_mat,tPACMat2.sPAC.DynamicPhase(:,(ind_time),:));
                        end
                    end
                end
                
            end
            tPACMat.nAvg = length(sInput);
            tPACMat.sPAC.DynamicNesting = Nesting;
            tPACMat.sPAC.DynamicPAC = PAC;
            if extract_phasePAC
                tPACMat.sPAC.DynamicPhase = Phase_mat;
            end
            tPACMat.Time = time(ind_time);
            clear Nesting PAC
        end


        % == EXTRACTING COMODULOGRAM ==
        tPACMat = Compute(tPACMat, inputTime, window_length, anal_type, doInterpolation);

        % === PLAYING THE RESULTS ===
        if tPACMat.time_resolved_comod
            limits = [min(tPACMat.sPAC.DirectPAC(:)), max(tPACMat.sPAC.DirectPAC(:))];
            handle = implay(squeeze(permute(tPACMat.sPAC.DirectPAC(1,:,:,:), [3,4,2,1])),5);
            handle.Visual.ColorMap.UserRangeMin = limits(1);
            handle.Visual.ColorMap.UserRangeMax = limits(2)*1.2;
            handle.Visual.ColorMap.UserRange = 1;
            handle.Visual.ColorMap.MapExpression = 'jet';
        end

        % === SAVING THE DATA IN BRAINSTORM ===
        % Get output study
        [sStudy, iStudy, Comment, uniqueDataFile] = bst_process('GetOutputStudy', sProcess, sInput);
        
        % Comment
        if isequal(inputTime, tPACMat.Time)
            tPACMat.Comment = [tPACMat.Comment, ' | ',tag];
        else
            tPACMat.Comment = [tPACMat.Comment, ' | ',tag,' | t=(', num2str(inputTime(1)), ',',  num2str(inputTime(2)),')'];
        end

        % Output filename: add file tag
        FileTag = strtrim(strrep(tag, '|', ''));        
        OutputFiles{1} = bst_process('GetNewFilename', bst_fileparts(sStudy.FileName), ['timefreq_pac_fullmaps']);
        OutputFiles{1} = file_unique(OutputFiles{1});        
        % Averaging results from the different data file: reset the "DataFile" field
        if isfield(tPACMat, 'DataFile') && ~isempty(tPACMat.DataFile) && (length(uniqueDataFile) ~= 1)
            tPACMat.DataFile = [];
        end        
        % Save file
        bst_save(OutputFiles{1}, tPACMat, 'v6');
        % Add file to database structure
        db_add_data(iStudy, OutputFiles{1}, tPACMat);
        
    elseif output_type==2 && length(sInput)>1
        for iFile = 1:length(sInput)
            % Load TF file
            tPACMat = in_bst_timefreq(sInput(iFile).FileName, 0);
            % Error
            Messages = 'Cannot load the file';
            if isempty(tPACMat)
                bst_report('Error', 'process_pac_comod', sInput, Messages);
                return;
            end
            
                        % check the file format
            indices = [];
            str = tPACMat.Comment;
            tags = {'avg';'mean';'median';'fpMap';'CoMod';'zscore'};
            for itag=1:length(tags)
                k = strfind(str,tags{itag});
                indices = [indices,k];
            end
            if ~isempty(indices) % it is a processed tpac map (e.g. comod or fp_map)                
                Message = ['File#',num2str(iFile),' is ignored becauase it is not a raw tPAC file'];
                bst_report('Warning', 'process_pac_fp_map', sInput, Message);
            else
            
                % == EXTRACTING COMODULOGRAM ==
                tPACMat = Compute(tPACMat, inputTime, window_length, anal_type, doInterpolation);
                
                % === PLAYING THE RESULTS ===
                if tPACMat.time_resolved_comod
                    limits = [min(tPACMat.sPAC.DirectPAC(:)), max(tPACMat.sPAC.DirectPAC(:))];
                    handle = implay(squeeze(permute(tPACMat.sPAC.DirectPAC(1,:,:,:), [3,4,2,1])),5);
                    handle.Visual.ColorMap.UserRangeMin = limits(1);
                    handle.Visual.ColorMap.UserRangeMax = limits(2)*1.2;
                    handle.Visual.ColorMap.UserRange = 1;
                    handle.Visual.ColorMap.MapExpression = 'jet';
                end
                
                % === SAVING THE DATA IN BRAINSTORM ===
                % Comment
%                 inputTime = t{1};
                if isequal(inputTime,tPACMat.Time)
                    tPACMat.Comment = [tPACMat.Comment, ' | ',tag];
                else
                    tPACMat.Comment = [tPACMat.Comment, ' | ',tag,' | t=(', num2str(inputTime(1)), ',',  num2str(inputTime(2)),')'];
                end
                tPACMat.FunctionVersion = sProcess.Comment;
                
                % Get output study
                [sStudy, iStudy] = bst_process('GetOutputStudy', sProcess, sInput(iFile));
                % Output filename: add file tag
                FileTag = strtrim(strrep(tag, '|', ''));
                OutputFiles{1} = bst_process('GetNewFilename', bst_fileparts(sStudy.FileName), 'timefreq_pac_fullmaps');
                OutputFiles{1} = file_unique(OutputFiles{1});
                
                % Save file
                bst_save(OutputFiles{1}, tPACMat, 'v6');
                % Add file to database structure
                db_add_data(iStudy, OutputFiles{1}, tPACMat);
            end
        end
    end
end


% == EXTRACTING COMODULOGRAM ==
function tPACMatOutput = Compute(tPACMat, inputTime, window_length, anal_type, doInterpolation)

    extract_phasePAC = 0;
    P = 98;         % percentile factor
    highFreq = tPACMat.sPAC.HighFreqs;
    OutputHighFreq = tPACMat.sPAC.HighFreqs;
    dynamicFp = tPACMat.sPAC.DynamicNesting;
    dynamicPAC = tPACMat.sPAC.DynamicPAC;
    if isfield(tPACMat.sPAC, 'DynamicPhase')
        dynamicPhase = tPACMat.sPAC.DynamicPhase;
        extract_phasePAC = 1;
    end
        
    % Check if tPAC map is interpolated, and if so remove the interpolated
    % points in fa direction
    if isfield(tPACMat.Options, 'PACoptions')
        wasInterp = tPACMat.Options.PACoptions.doInterpolation;
        if wasInterp 
            ind = 1:2:length(highFreq);
            highFreq = highFreq(ind);
            dynamicFp = dynamicFp(:,:,ind,:,:);
            dynamicPAC = dynamicPAC(:,:,ind,:,:); 
            if extract_phasePAC
                dynamicPhase  = dynamicPhase (:,:,ind,:,:);
            end
        end
    else
        wasInterp = 0;
    end

    
    nA = length(highFreq); 
%     inputTime = t{1};
    timeRange = bst_closest(inputTime, tPACMat.Time);
    if length(timeRange)==1
       timeRange = [timeRange, timeRange]; 
    elseif tPACMat.Time(timeRange(2)) > inputTime(2)
        timeRange(2) = timeRange(2)-1;
    end
    
    if window_length == 0
        tPACMat.time_resolved_comod = 0; 
        nWindow = 1;
        index = timeRange;
    else
        tPACMat.time_resolved_comod = 1;
        %         nWindow = fix([tPACMat.Time(timeRange(2))-tPACMat.Time(timeRange(1))]/window_length);
        w = tPACMat.Time(timeRange(1)): window_length: tPACMat.Time(timeRange(2));  % windows
        nWindow = length(w)-1;
        index = bst_closest(w, tPACMat.Time);
        tPACMat.sPAC.DirectPACTime = (tPACMat.Time(index(1:end-1))+tPACMat.Time(index(2:end)))/2;
    end

    tRange = timeRange;
    if length(size(dynamicFp))==5 && length(size(dynamicPAC))==5
        NestingF = reshape(permute(dynamicFp(:,tRange(1):tRange(2),:,:,:),[3,1,2,4,5]),nA,[]);
        pacValue = reshape(permute(dynamicPAC(:,tRange(1):tRange(2),:,:,:),[3,1,2,4,5]),nA,[]);
        if extract_phasePAC
            PhasePAC = reshape(permute(dynamicPhase(:,tRange(1):tRange(2),:,:,:),[3,1,2,4,5]),nA,[]);
        end

    elseif length(size(dynamicFp))==5 && length(size(dynamicPAC))==4
        NestingF = reshape(permute(dynamicFp(:,tRange(1):tRange(2),:,:,:),[3,1,2,4,5]),nA,[]);
        pacValue = reshape(permute(repmat(dynamicPAC(:,tRange(1):tRange(2),:,:),[1,1,1,1,size(dynamicFp,5)]),[3,1,2,4,5]),nA,[]);
        if extract_phasePAC
            PhasePAC = reshape(permute(dynamicPhase(:,tRange(1):tRange(2),:,:,:),[3,1,2,4,5]),nA,[]);
        end
    else
        NestingF = reshape(permute(dynamicFp(:,tRange(1):tRange(2),:,:),[3,1,2,4]),nA,[]);
        pacValue = reshape(permute(repmat(dynamicPAC(:,tRange(1):tRange(2),:,:),[1,1,1,size(dynamicFp,4)]),[3,1,2,4]),nA,[]);
        if extract_phasePAC
            PhasePAC = reshape(permute(dynamicPhase(:,tRange(1):tRange(2),:,:),[3,1,2,4]),nA,[]);
        end
    end
    
        % Maximum resolution for output fp
    OutputmaxRes = (tPACMat.Options.BandNesting(2)-tPACMat.Options.BandNesting(1))/.25;    

    if doInterpolation
        OutputFp = linspace(tPACMat.Options.BandNesting(1), tPACMat.Options.BandNesting(2), OutputmaxRes);
    end

    % Extracting fP centers
    res = 1/tPACMat.Options.WinLen;
    NfpMax = fix((tPACMat.Options.BandNesting(2)-tPACMat.Options.BandNesting(1))/res);
    
    [h, freqCent] = hist(NestingF(:), NfpMax);  %1000
    fPcenters = freqCent;%(h>median(h(h>0))/4);


    % Former algorithm    
    fPcenters = freqCent;%(h>median(h(h>0))/4);
            
    % Setting the maximum resolution
    if length(fPcenters)>(OutputmaxRes-2)
        fPcenters =  fPcenters(1:fix(length(fPcenters)/OutputmaxRes):end);   % downsampling for the map
    end 
    fPcenters = unique(fPcenters);        

    % Adding first and last point to the range
    fPcenters = [(tPACMat.Options.BandNesting(1)+fPcenters(1))/2, fPcenters, (tPACMat.Options.BandNesting(end)+fPcenters(end))/2];%making similar range for all cases

    fP = [tPACMat.Options.BandNesting(1), ...
        (fPcenters(1:end-1) + fPcenters(2:end))/2, ...
        tPACMat.Options.BandNesting(2)];
    fP = unique(fP);
    nP = length(fP);
    
    for iWindow = 1:nWindow
        tRange = [index(iWindow), index(iWindow+1)];
        
        if anal_type ==1
            
            if nWindow>1
                if length(size(dynamicFp))==5 && length(size(dynamicPAC))==5
                    NestingF = reshape(permute(dynamicFp(:,tRange(1):tRange(2),:,:,:),[3,1,2,4,5]),nA,[]);
                    pacValue = reshape(permute(dynamicPAC(:,tRange(1):tRange(2),:,:,:),[3,1,2,4,5]),nA,[]);
                    if extract_phasePAC
                        PhasePAC = reshape(permute(dynamicPhase(:,tRange(1):tRange(2),:,:,:),[3,1,2,4,5]),nA,[]);
                    end
                    
                elseif length(size(dynamicFp))==5 && length(size(dynamicPAC))==4
                    NestingF = reshape(permute(dynamicFp(:,tRange(1):tRange(2),:,:,:),[3,1,2,4,5]),nA,[]);
                    pacValue = reshape(permute(repmat(dynamicPAC(:,tRange(1):tRange(2),:,:),[1,1,1,1,size(dynamicFp,5)]),[3,1,2,4,5]),nA,[]);
                    if extract_phasePAC
                        PhasePAC = reshape(permute(dynamicPhase(:,tRange(1):tRange(2),:,:,:),[3,1,2,4,5]),nA,[]);
                    end
                else
                    NestingF = reshape(permute(dynamicFp(:,tRange(1):tRange(2),:,:),[3,1,2,4]),nA,[]);
                    pacValue = reshape(permute(repmat(dynamicPAC(:,tRange(1):tRange(2),:,:),[1,1,1,size(dynamicFp,4)]),[3,1,2,4]),nA,[]);
                    if extract_phasePAC
                        PhasePAC = reshape(permute(dynamicPhase(:,tRange(1):tRange(2),:,:),[3,1,2,4]),nA,[]);
                    end
                end                            
            end
            
            pacValue(isnan(pacValue)) = 0;
            if extract_phasePAC
                PhasePAC(isnan(PhasePAC)) = 0;
            end
            CoMod = zeros(nA,nP-1);
            CoModPhase = zeros(nA,nP-1);
            Phase = zeros(nA,nP-1);
            for iFp = 1:nP-1
                [ind, indA] = find(NestingF'>fP(iFp) & NestingF'<fP(iFp+1));  % indA: index of Acenter, ind: index of value
                for iFa = min(indA):max(indA)
                    indF = ind(indA==iFa);
                    CoMod(iFa,iFp) = sum(pacValue(iFa,indF));
                    if extract_phasePAC
                        CoModPhase(iFa,iFp) = sum(pacValue(iFa,indF).*exp(1i*PhasePAC(iFa,indF)));
                        Phase(iFa,iFp) = angle(CoModPhase(iFa,iFp));
                    end
                end
            end
            CoMod = CoMod/(size(NestingF,2)*size(NestingF,3)*size(NestingF,4)*size(NestingF,5));
            if extract_phasePAC
                CoModPhase = abs(CoModPhase)/(size(NestingF,2)*size(NestingF,3)*size(NestingF,4)*size(NestingF,5));
            end
            
            if doInterpolation || wasInterp
                % Interpolation
                [X,Y] = meshgrid(fPcenters, highFreq);
                if doInterpolation
                    nx = OutputFp;
                else
                    nx = fPcenters;
                end
                ny = OutputHighFreq;
                [nX,nY] = meshgrid(nx,ny);
                CoMod = interp2(X,Y,CoMod,nX,nY,'linear',0);
                if extract_phasePAC
                    CoModPhase = interp2(X,Y,CoModPhase,nX,nY,'linear',0);
                    InterpPhase = interp2(X,Y,Phase,nX,nY,'linear',0);
                end
            end
            if ~(doInterpolation)
                OutputFp = fPcenters;
            end
            
            % Output parameters
            if extract_phasePAC
                tPACMat.sPAC.CouplingPhase = InterpPhase';
                tPACMat.sPAC.DirectPAC(1,iWindow,:,:)   = CoModPhase';
                [tPACMat.TF, maxInd] = max(CoModPhase(:));
                [indFa, indFp] = ind2sub(size(CoModPhase), maxInd);
                tPACMat.sPAC.NestingFreq = OutputFp(indFp);
                tPACMat.sPAC.NestedFreq = OutputHighFreq(indFa);
                
            else
                tPACMat.sPAC.DirectPAC(1,iWindow,:,:)   = CoMod';
                [tPACMat.TF, maxInd] = max(CoMod(:));
                [indFa, indFp] = ind2sub(size(CoMod), maxInd);
                tPACMat.sPAC.NestingFreq = OutputFp(indFp);
                tPACMat.sPAC.NestedFreq = OutputHighFreq(indFa);                
            end
            
        else
            nSources = size(dynamicFp,1);
            tPACMat.TF = zeros(nSources,1);            
            for iSource =1:nSources                
                if length(size(dynamicFp))==5 && length(size(dynamicPAC))==5
                    NestingF = reshape(permute(dynamicFp(iSource,tRange(1):tRange(2),:,:,:),[3,1,2,4,5]),nA,[]);
                    pacValue = reshape(permute(dynamicPAC(iSource,tRange(1):tRange(2),:,:,:),[3,1,2,4,5]),nA,[]);
                    if extract_phasePAC
                        PhasePAC = reshape(permute(dynamicPhase(iSource,tRange(1):tRange(2),:,:,:),[3,1,2,4,5]),nA,[]);
                    end
                    
                elseif length(size(dynamicFp))==5 && length(size(dynamicPAC))==4
                    NestingF = reshape(permute(dynamicFp(iSource,tRange(1):tRange(2),:,:,:),[3,1,2,4,5]),nA,[]);
                    pacValue = reshape(permute(repmat(dynamicPAC(iSource,tRange(1):tRange(2),:,:),[1,1,1,1,size(dynamicFp,5)]),[3,1,2,4,5]),nA,[]);
                    if extract_phasePAC
                        PhasePAC = reshape(permute(dynamicPhase(iSource,tRange(1):tRange(2),:,:,:),[3,1,2,4,5]),nA,[]);
                    end
                    
                else
                    NestingF = reshape(permute(dynamicFp(iSource,tRange(1):tRange(2),:,:),[3,1,2,4]),nA,[]);
                    pacValue = reshape(permute(repmat(dynamicPAC(iSource,tRange(1):tRange(2),:,:),[1,1,1,size(dynamicFp,4)]),[3,1,2,4]),nA,[]);
                    if extract_phasePAC
                        PhasePAC = reshape(permute(dynamicPhase(iSource,tRange(1):tRange(2),:,:),[3,1,2,4]),nA,[]);
                    end
                end
                
                pacValue(isnan(pacValue)) = 0;
                if extract_phasePAC
                    PhasePAC(isnan(PhasePAC)) = 0;
                end
                CoMod = zeros(nA,nP-1);
                CoModPhase = zeros(nA,nP-1);
                Phase = zeros(nA,nP-1);
                
                for iFp = 1:nP-1
                    [ind, indA] = find(NestingF'>fP(iFp) & NestingF'<fP(iFp+1));  % indA: index of Acenter, ind: index of value
                    for iFa = min(indA):max(indA)
                        indF = ind(indA==iFa);
                        CoMod(iFa,iFp) = sum(pacValue(iFa,indF));
                        if extract_phasePAC
                            CoModPhase(iFa,iFp) = sum(pacValue(iFa,indF).*exp(1i*PhasePAC(iFa,indF)));
                            Phase(iFa,iFp) = angle(CoModPhase(iFa,iFp));
                        end
                    end
                end
                CoMod = CoMod/(size(NestingF,2)*size(NestingF,3)*size(NestingF,4)*size(NestingF,5));%xl*100;
                if extract_phasePAC
                    CoModPhase = abs(CoModPhase)/(size(NestingF,2)*size(NestingF,3)*size(NestingF,4)*size(NestingF,5));
                end

                if doInterpolation || wasInterp
                    % Interpolation
                    [X,Y] = meshgrid(fPcenters, highFreq); 
                    if doInterpolation
                        nx = OutputFp;
                    else
                        nx = fPcenters;
                    end
                    ny = OutputHighFreq;
                    [nX,nY] = meshgrid(nx,ny);
                    CoMod = interp2(X,Y,CoMod,nX,nY,'linear',0);
                    if extract_phasePAC
                        CoModPhase = interp2(X,Y,CoModPhase,nX,nY,'linear',0);
                        InterpPhase = interp2(X,Y,Phase,nX,nY,'linear',0);
                    end
                end
                if ~(doInterpolation)
                    OutputFp = fPcenters;
                end
                
                % Output parameters
                if extract_phasePAC
                    [tPACMat.TF(iSource), maxInd] = max(CoModPhase(:));
                    [indFa, indFp] = ind2sub(size(CoModPhase), maxInd);
                    tPACMat.sPAC.NestingFreq(iSource,1) = OutputFp(indFp);
                    tPACMat.sPAC.NestedFreq(iSource,1) = OutputHighFreq(indFa);
                    tPACMat.sPAC.CouplingPhase(iSource,iWindow,:,:) = InterpPhase';
                    tPACMat.sPAC.DirectPAC(iSource,iWindow,:,:)   = CoModPhase';
                else
                    [tPACMat.TF(iSource), maxInd] = max(CoMod(:));
                    [indFa, indFp] = ind2sub(size(CoMod), maxInd);
                    tPACMat.sPAC.NestingFreq(iSource,1) = OutputFp(indFp);
                    tPACMat.sPAC.NestedFreq(iSource,1) = OutputHighFreq(indFa);
                    tPACMat.sPAC.DirectPAC(iSource,iWindow,:,:)   = CoMod';                    
                end
            end
            
        end
    end
    
    
    tPACMat.sPAC.LowFreqs = OutputFp;
    tPACMat.Time = tPACMat.Options.TimeWindow;
    
    tPACMatOutput = tPACMat;
    tPACMatOutput.extract_phasePAC =  extract_phasePAC;
end
