function varargout = process_pac_fp_map( varargin )
% process_pac_fp_map: Extract frequency for phase map from tPAC matrices.
%
% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c) University of Southern California & McGill University
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
% Authors: Soheila Samiee, 2014-2017
% v 2.1: SS, A bug in including multiple trials in analysis is fixed,
%              Nov. 2016
% 
% v 2.2: SS, Same resolution in fp direction as comod, Dec. 2016
% v 3.1: SS, change in resolution
% v 3.2: SS, Separate files is improved
% v 3.3: SS, a bug fixed , May 2017
% v 4.0: SS, applying a factor to compensate filter effect
% v 4.1: SS, new way of normalizing the maps, May 2017
% v 4.2: SS, Previous version of normalizing, Aug 2017
% v 5.0: SS, tPAC package, Aug 2017
% v 6.0: SS, Check for file format before using it for fp estimation, Sep
%            2017
% v 6.1: SS, Bug fix in time definition, Nov. 2017

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
% Description the process
sProcess.Comment     = 'Extracting fp-maps from tPAC maps';
sProcess.FileTag     = '';
sProcess.Category    = 'Custom';
sProcess.SubGroup    = {'Frequency','Time-resolved Phase-Amplitude Coupling'};
sProcess.Index       = 1021;
% Definition of the input accepted by this process
sProcess.InputTypes  = {'timefreq'};
sProcess.OutputTypes = {'timefreq'};
sProcess.nInputs     = 1;
sProcess.nMinFiles   = 1;
sProcess.isSeparator = 1;

% === TIME WINDOW
sProcess.options.fawindow.Comment = 'Frequency for amplitude range:';
sProcess.options.fawindow.Type    = 'range';
sProcess.options.fawindow.Value   = {[0 0], 'Hz', 2};
sProcess.options.label1.Comment = '(with entering [0,0], algorithm use the input f_A range) ';
sProcess.options.label1.Type    = 'label';

% === The sources
sProcess.options.label.Comment = '<U><B> Method </B></U>';
sProcess.options.label.Type    = 'label';
sProcess.options.analyze_type.Comment = {'All sources/channels together', 'Each source/channel separately'};
sProcess.options.analyze_type.Type    = 'radio';
sProcess.options.analyze_type.Value   = 1;

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
    faBand = sProcess.options.fawindow.Value;
    anal_type = sProcess.options.analyze_type.Value;
    doInterpolation = sProcess.options.doInterp.Value;
    
    if anal_type == 1
        cat_dim = 1;
    else
        cat_dim = 5;
    end
    

    % Set the tag
    tag = 'fpMap';

    % Load TF file
    tPACMat = in_bst_timefreq(sInput(1).FileName, 0);
    % Error
    if isempty(tPACMat)
        bst_report('Error', 'process_pac_fp_map', sInput, Messages);
        return;
    end
    time = tPACMat.Time;
    PAC = [];    
    extract_phasePAC = 0;
    
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
            if ~isempty(indices) % Ignore file because it is a processed tpac map (e.g. comod or fp_map)                
                Message = ['File#',num2str(iFile),' is ignored becauase it is not a raw tPAC file'];
                bst_report('Warning', 'process_pac_fp_map', sInput, Message);
                
            elseif isempty(PAC)  % filling the variables based on the first file               
                time = tPACMat.Time;
                Nesting = tPACMat.sPAC.DynamicNesting;
                PAC = tPACMat.sPAC.DynamicPAC;
                if isfield(tPACMat.sPAC, 'DynamicPhase')
                    extract_phasePAC = 1;
                    Phase_mat = tPACMat.sPAC.DynamicPhase;
                end
                
            else                
               tPACMat2 = in_bst_timefreq(sInput(iFile).FileName, 0);
               % Check if time and frequency definition of the current file
               % matches the first file
               time = tPACMat2.Time;
               fa = tPACMat2.sPAC.HighFreqs;
               if ~isequal(time,tPACMat.Time) || ~isequal(fa,tPACMat.sPAC.HighFreqs)
                   Message = ['File#',num2str(iFile),' is ignored becauase its format does not match the first file (time)'];
                   bst_report('Warning', 'process_pac_fp_map', sInput, Message);
               elseif ~isequal(size(Nesting,1),size(tPACMat2.sPAC.DynamicNesting,1)) && cat_dim~=1
                   Message = ['File#',num2str(iFile),' is ignored becauase its format does not match the first file (Number of channels)'];
                   bst_report('Warning', 'process_pac_fp_map', sInput, Message);
               elseif ~isequal(size(Nesting,3), size(tPACMat2.sPAC.DynamicNesting,3)) || ~isequal(size(Nesting,4), size(tPACMat2.sPAC.DynamicNesting,4))
                   Message = ['File#',num2str(iFile),' is ignored becauase its format does not match the first file'];
                   bst_report('Warning', 'process_pac_fp_map', sInput, Message);
               elseif ~isequal(size(Nesting,5), size(tPACMat2.sPAC.DynamicNesting,5)) && cat_dim~=5
                   Message = ['File#',num2str(iFile),' is ignored becauase its format does not match the first file'];
                   bst_report('Warning', 'process_pac_fp_map', sInput, Message);
               else
                   Nesting = cat(cat_dim,Nesting,tPACMat2.sPAC.DynamicNesting);
                   PAC = cat(cat_dim,PAC,tPACMat2.sPAC.DynamicPAC);
                   if extract_phasePAC
                       Phase_mat = cat(cat_dim,Phase_mat,tPACMat2.sPAC.DynamicPhase);
                   end
               end
           end
        end
       tPACMat.sPAC.DynamicNesting = Nesting;
       tPACMat.sPAC.DynamicPAC = PAC;
       if extract_phasePAC
           tPACMat.sPAC.DynamicPhase = Phase_mat;
       end

       clear Nesting PAC Phase_mat
    end

    highFreq = tPACMat.sPAC.HighFreqs;
    
    
    dynamicFp = tPACMat.sPAC.DynamicNesting;
    dynamicPAC = tPACMat.sPAC.DynamicPAC;
    if extract_phasePAC
        dynamicPhase = tPACMat.sPAC.DynamicPhase;
    end
        
    
    % == EXTRACTING Fp map ==
    % Parameters
    OriginialFaBand = [min(highFreq), max(highFreq)];
    if iscell(faBand)
        if isequal(faBand{1},[0,0])
            faBand = OriginialFaBand;
        elseif isequal(faBand{1}(1),0)
            faBand = [OriginialFaBand(1), faBand{1}(2)];
        elseif isequal(faBand{1}(2),0)
            faBand = [faBand{1}(1), OriginialFaBand(2)];
        else
            faBand = faBand{1};
        end
    else
        if isequal(faBand,[0,0])
            faBand = OriginialFaBand;
        end
    end
    nT = length(tPACMat.sPAC.TimeOut);
    faInd = find(highFreq>=faBand(1) & highFreq<=faBand(2));
    
    
    if length(size(dynamicFp))==5 && length(size(dynamicPAC))==5
        NestingF = reshape(permute(dynamicFp(:,:,faInd,:,:),[2,1,3,4,5]),nT,[]);
        pacValue = reshape(permute(dynamicPAC(:,:,faInd,:,:),[2,1,3,4,5]),nT,[]);
        if extract_phasePAC
            PhasePAC  = reshape(permute(dynamicPhase(:,:,faInd,:,:),[2,1,3,4,5]),nT,[]);
        end
        
    elseif length(size(dynamicFp))==5 && length(size(dynamicPAC))==4
        NestingF = reshape(permute(dynamicFp(:,:,faInd,:,:),[2,1,3,4,5]),nT,[]);
        pacValue = reshape(permute(repmat(dynamicPAC(:,:,faInd,:),[1,1,1,1,size(dynamicFp,5)]),[2,1,3,4,5]),nT,[]);
        if extract_phasePAC
            PhasePAC = reshape(permute(dynamicPhase(:,:,faInd,:,:),[2,1,3,4,5]),nT,[]);
        end
        
    else
        NestingF = reshape(permute(dynamicFp(:,:,faInd,:),[2,1,3,4]),nT,[]);
        pacValue = reshape(permute(repmat(dynamicPAC(:,:,faInd,:),[1,1,1,size(dynamicFp,4)]),[2,1,3,4]),nT,[]);
        if extract_phasePAC
            PhasePAC = reshape(permute(dynamicPhase(:,:,faInd,:),[2,1,3,4]),nT,[]);
        end
    end 

    % Extracting fP centers
    res = 1/tPACMat.Options.WinLen;
    NfpMax = fix((tPACMat.Options.BandNesting(2)-tPACMat.Options.BandNesting(1))/res);
    
    [h, freqCent] = hist(NestingF(:), NfpMax);  %1000
    fPcenters = freqCent;%(h>median(h(h>0))/4);

    % Adding first and last point to the range
    fPcenters = [(tPACMat.Options.BandNesting(1)+fPcenters(1))/2, fPcenters, (tPACMat.Options.BandNesting(end)+fPcenters(end))/2];%making similar range for all cases
    
    % Setting the maximum resolution
    maxRes = (tPACMat.Options.BandNesting(2)-tPACMat.Options.BandNesting(1))/.25;    % maximum resolution = 0.25 Hz
    if length(fPcenters)>maxRes
        fPcenters =  fPcenters(1:fix(length(fPcenters)/maxRes):end);   % downsampling for the map
    end

    fP = [tPACMat.Options.BandNesting(1), ...
        (fPcenters(1:end-1) + fPcenters(2:end))/2, ...
        tPACMat.Options.BandNesting(2)];
    fP = unique(fP);
    nP = length(fP);
 
    filter_ratio = ceil(0.15*highFreq./[mean(diff(highFreq))]); % compensate for filter_rolloff_effect
    filter_ratio = filter_ratio(end:-1:1)/max(filter_ratio);
    filter_ratio = (filter_ratio+1)/2;
    filter_ratio = filter_ratio+1-min(filter_ratio);
    filter_ratio = repmat(filter_ratio,[size(dynamicPAC,1),1,size(dynamicPAC,4), size(dynamicPAC,5)]); %length(tPACMat.RowNames)
    filter_ratio = filter_ratio(:)';
    
                 % Maximum resolution for output fp
    OutputmaxRes = (tPACMat.Options.BandNesting(2)-tPACMat.Options.BandNesting(1))/.25;    

    if doInterpolation
        OutputFp = linspace(tPACMat.Options.BandNesting(1), tPACMat.Options.BandNesting(2), OutputmaxRes);
    end

    
    if anal_type ==1
        FpMap = zeros(nT,nP-1);
        FpMapPhase = zeros(nT,nP-1);
        Phase = zeros(nT,nP-1);
        for iFp = 1:nP-1
            [ind, indT] = find(NestingF'>fP(iFp) & NestingF'<fP(iFp+1));  % indA: index of Acenter, ind: index of value
            for iT = min(indT):max(indT)
                indF = ind(indT==iT);
                FpMap(iT,iFp) = sum(filter_ratio(indF).*pacValue(iT,indF));
                if extract_phasePAC
                    FpMapPhase(iT,iFp) = sum(filter_ratio(indF).*pacValue(iT,indF).*exp(1i*PhasePAC(iT,indF)));
                    Phase(iT,iFp) = angle(FpMapPhase(iT,iFp));
                end
            end
        end
        FpMap = FpMap/(size(NestingF,2)*size(NestingF,3)*size(NestingF,4)*size(NestingF,5));
        
        if extract_phasePAC
            FpMapPhase = abs(FpMapPhase)/(size(dynamicFp,2)*size(dynamicFp,3)*size(dynamicFp,4)*size(dynamicFp,5));
        end
          
        if extract_phasePAC
            tmp(1,:,:) = FpMapPhase;         
        else
            tmp(1,:,:) = FpMap;   
        end
        
        if doInterpolation
            [X,Y] = meshgrid(time,fPcenters);
            nx = time;
            ny = OutputFp;
            [nX,nY] = meshgrid(nx,ny);
            tmp2(1,:,:) = interp2(X,Y,squeeze(tmp)',nX,nY,'linear',0)';
            if extract_phasePAC
                Phase = interp2(X,Y,Phase',nX,nY,'linear',0);
            end
            tmp = tmp2;
        else
            OutputFp = fPcenters;
        end
        
        % Output parameters
        if extract_phasePAC
            tPACMat.sPAC.CouplingPhase = Phase';
        end
        
        tPACMat.sPAC.DynamicPAC = tmp;
        tPACMat.sPAC.HighFreqs = OutputFp;
        tPACMat.TF =  max(squeeze(tmp),[],2)';
        
    else
        tPACMat.sPAC.DynamicPAC = [];
        nSources = size(dynamicFp,1);
        tPACMat.TF = zeros(nSources,nT);
        FpMapPhase = zeros(nT,nP-1);
        Phase = zeros(nT,nP-1);
        
        for iSource =1:nSources
             
            if length(size(dynamicFp))==5 && length(size(dynamicPAC))==5
                NestingF = reshape(permute(dynamicFp(iSource,:,faInd,:,:),[2,1,3,4,5]),nT,[]);
                pacValue = reshape(permute(dynamicPAC(iSource,:,faInd,:,:),[2,1,3,4,5]),nT,[]);
                if extract_phasePAC
                    PhasePAC  = reshape(permute(dynamicPhase(:,:,faInd,:,:),[2,1,3,4,5]),nT,[]);
                end
                
            elseif length(size(dynamicFp))==5 && length(size(dynamicPAC))==4
                NestingF = reshape(permute(dynamicFp(iSource,:,faInd,:,:),[2,1,3,4,5]),nT,[]);
                pacValue = reshape(permute(repmat(dynamicPAC(iSource,:,faInd,:),[1,1,1,1,size(dynamicFp,5)]),[2,1,3,4,5]),nT,[]);
                if extract_phasePAC
                    PhasePAC = reshape(permute(dynamicPhase(:,:,faInd,:,:),[2,1,3,4,5]),nT,[]);
                end
            else
                NestingF = reshape(permute(dynamicFp(iSource,:,faInd,:),[2,1,3,4]),nT,[]);
                pacValue = reshape(permute(repmat(dynamicPAC(iSource,:,faInd,:),[1,1,1,size(dynamicFp,4)]),[2,1,3,4]),nT,[]);
                if extract_phasePAC
                    PhasePAC = reshape(permute(dynamicPhase(:,:,faInd,:),[2,1,3,4]),nT,[]);
                end
            end           
            
            FpMap = zeros(nT,nP-1);
        
            for iFp = 1:nP-1
                [ind, indT] = find(NestingF'>fP(iFp) & NestingF'<fP(iFp+1));  % indA: index of Acenter, ind: index of value
                for iT = min(indT):max(indT)
                    indF = ind(indT==iT);                    
                    FpMap(iT,iFp) = sum(filter_ratio(indF).*pacValue(iT,indF));
                    if extract_phasePAC
                        FpMapPhase(iT,iFp) = sum(filter_ratio(indF).*pacValue(iT,indF).*exp(1i*PhasePAC(iT,indF)));
                        Phase(iT,iFp) = angle(FpMapPhase(iT,iFp));
                    end
                end
            end
            FpMap = FpMap/(size(dynamicFp,2)*size(dynamicFp,3)*size(dynamicFp,4)*size(dynamicFp,5));                        
            if extract_phasePAC
                FpMapPhase = abs(FpMapPhase)/(size(dynamicFp,2)*size(dynamicFp,3)*size(dynamicFp,4)*size(dynamicFp,5));
            end
            
            if extract_phasePAC
                [tPACMat.TF(iSource,:)] = max(FpMapPhase,[],2)';
                tmp(1,:,:) = FpMapPhase; % permute(FpMap,[2,1]);
            else
                [tPACMat.TF(iSource,:)] = max(FpMap,[],2)';
                tmp(1,:,:) = FpMap; % permute(FpMap,[2,1]);
            end
            
            
            if doInterpolation
                [X,Y] = meshgrid(time,fPcenters);
                nx = time;
                ny = OutputFp;
                [nX,nY] = meshgrid(nx,ny);
                tmp2(1,:,:) = interp2(X,Y,squeeze(tmp)',nX,nY,'linear',0)';
                if extract_phasePAC
                    InterpPhase = interp2(X,Y,Phase',nX,nY,'linear',0);
                end
            else
                OutputFp = fPcenters;
            end
            
            % Output parameters
            if extract_phasePAC
                tPACMat.sPAC.CouplingPhase = InterpPhase';
            end            
            tPACMat.sPAC.DynamicPAC(iSource,:,:) = tmp2;
            tPACMat.sPAC.HighFreqs = OutputFp;
%             tPACMat.TF(iSource,:,:) = squeeze(tmp2);
            
        end
        
    end
    tPACMat.sPAC.LowFreqs = fPcenters;
     
    faBand(1) = max(faBand(1),highFreq(1));
    faBand(end) = min(faBand(end),highFreq(end));
    
    tPACMat.sPAC.NewFaRange = faBand;
    
    % === SAVING THE DATA IN BRAINSTORM ===
    % Comment
    if isequal(faBand,OriginialFaBand)
        tPACMat.Comment = [tPACMat.Comment, ' | ',tag];
    else
        tPACMat.Comment = [tPACMat.Comment, ' | ',tag,' | fa=[', num2str(faBand(1)), ',',  num2str(faBand(2)),']'];
    end
    tPACMat.FunctionVersion = sProcess.Comment;

    % Get output study
    [sStudy, iStudy, Comment, uniqueDataFile] = bst_process('GetOutputStudy', sProcess, sInput);
    
    % Output filename: add file tag
    FileTag = strtrim(strrep(tag, '|', ''));
    OutputFiles{1} = bst_process('GetNewFilename', bst_fileparts(sStudy.FileName), ['timefreq_dpac_fullmaps', FileTag]);
    OutputFiles{1} = file_unique(OutputFiles{1});
    
    % Averaging results from the different data file: reset the "DataFile" field
    if isfield(tPACMat, 'DataFile') && ~isempty(tPACMat.DataFile) && (length(uniqueDataFile) ~= 1)
        tPACMat.DataFile = [];
    end
        
    % Save file
    bst_save(OutputFiles{1}, tPACMat, 'v6');
    % Add file to database structure
    db_add_data(iStudy, OutputFiles{1}, tPACMat);
end
