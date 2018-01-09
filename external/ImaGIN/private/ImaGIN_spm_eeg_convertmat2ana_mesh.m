function OutputFiles = ImaGIN_spm_eeg_convertmat2ana_mesh(S)
% Export intracerebral EEG recordings as a mesh in a .gii file

% -=============================================================================
% This function is part of the ImaGIN software: 
% https://f-tract.eu/
%
% This software is distributed under the terms of the GNU General Public License
% as published by the Free Software Foundation. Further details on the GPLv3
% license can be found at http://www.gnu.org/copyleft/gpl.html.
%
% FOR RESEARCH PURPOSES ONLY. THE SOFTWARE IS PROVIDED "AS IS," AND THE AUTHORS
% DO NOT ASSUME ANY LIABILITY OR RESPONSIBILITY FOR ITS USE IN ANY CONTEXT.
%
% Copyright (c) 2000-2018 Inserm U1216
% =============================================================================-
%
% Authors: Stefan Kiebel, 2005  (for spm_eeg_convertmat2ana.m)
%          Olivier David        (adaptation for SEEG)
%          Francois Tadel, 2017

% Returned variable
OutputFiles = {};

%% ===== INPUT PARAMETERS =====
try
    Fname = S.Fname;
catch
    Fname = spm_select(inf, '\.mat$', 'Select EEG mat file');
end

try 
    MeshFile = S.MeshFile;
catch
    MeshFile = spm_select(1, '\.gii$', 'Select cortex surface');
end

try
    SizeHorizon = S.SizeHorizon;
catch
    SizeHorizon = spm_input('Size of spatial horizon [mm]', '+1', 'n', '10', 1);
end

try
    TimeWindow = S.TimeWindow;
catch
    TimeWindow = spm_input('Time window positions [sec]', '+1', 'r');
end

try
    TimeWindowWidth = S.TimeWindowWidth;
catch
    TimeWindowWidth = spm_input('Time window width [sec]', '+1', 'r');
end

try
    SmoothIterations = S.SmoothIterations;
catch
    SmoothIterations = spm_input('Smoothing parameter', '+1', 'r', 0);
end


%% ===== CONVERT TO MESH TEXTURE =====
spm('Pointer', 'Watch'); 
drawnow

% Load data set into structures
for k = 1:size(Fname, 1)
    % Load mesh
    gii = gifti(MeshFile);
    GL  = spm_mesh_smooth(gii);
    
    % Load data set
    D = spm_eeg_load(deblank(Fname(k,:)));
    
    % Use all the time points by default
    if isempty(TimeWindow)
        timewindow = D.time;
    else
        timewindow = TimeWindow;
    end
    % Select time window
    if isfield(D,'time')
        time = D.time;
    else
        time = 0:1/D.fsample:(D.nsamples-1)/D.fsample;
        time = time+D.timeonset;
    end
    for i1=1:length(timewindow)
        [tmp, timewindow(i1)] = min(abs(time-TimeWindow(i1)));
    end
    timewindow = unique(timewindow);
    timewindowwidth = round(TimeWindowWidth*D.fsample/2);
    
%%%%% OLD VERSION %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%     % Select SEEG channels
%     Ctf = sensors(D,'EEG');
%     Bad = badchannels(D);
%     iGood = setdiff(setdiff(1:nchannels(D),indchantype(D,'ECG')),Bad);
%     % Keep only the contacts that are close to the cortex
%     Index = cell(1,nchannels(D)-length(indchantype(D,'ECG')));
%     Distance = cell(1,nchannels(D)-length(indchantype(D,'ECG')));
%     for i1 = iGood
%         d = sqrt(sum((gii.vertices-ones(size(gii.vertices,1),1)*Ctf.elecpos(i1,:)).^2,2));
%         Distance{i1} = min(d);
%         if (Distance{i1} <= SizeHorizon)
%             Index{i1} = find(d==min(d))';
%             Distance{i1} = Distance{i1}*ones(1,length(Index{i1}));
%         end
%     end
%     % Select vertices of the mesh
%     ok=1;
%     while ok
%         ok=0;
%         IndexConn = cell(1,length(Index));
%         IndexNew = cell(1,length(Index));
%         DistanceNew = cell(1,length(Index));
%         % Grow selection in a volume
%         for i1 = iGood
%             for i2 = 1:length(Index{i1})
%                 IndexConn{i1} = unique([IndexConn{i1} find(GL(Index{i1}(i2),:))]);
%             end
%             IndexNew{i1} = setdiff(IndexConn{i1},Index{i1});
%             d = sqrt(sum((gii.vertices(IndexNew{i1},:)-ones(length(IndexNew{i1}),1)*Ctf.elecpos(i1,:)).^2,2));
%             DistanceNew{i1} = d';
%             DistanceNew{i1} = DistanceNew{i1}(find(d<=SizeHorizon));
%             IndexNew{i1} = IndexNew{i1}(find(d<=SizeHorizon));
%             if ~isempty(IndexNew{i1})
%                 ok = 1;
%                 Index{i1} = [Index{i1} IndexNew{i1}];
%                 Distance{i1} = [Distance{i1} DistanceNew{i1}];
%             end
%         end
%     end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    

%%% NEW OPTIMIZED VERSION %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Select SEEG channels
    Dsensors = sensors(D,'EEG');
    iGood = setdiff(1:nchannels(D), [indchantype(D,'ECG'), badchannels(D)]);
    elecpos = Dsensors.elecpos;
    nChan = size(elecpos,1);
    % Get vertices in the neighborhood of each contact
    Index = cell(1, nChan);
    Distance = cell(1, nChan);
    for iChan = iGood
        % Compute distance contact/vertices
        d2 = sum(bsxfun(@minus, gii.vertices, elecpos(iChan,:)) .^ 2, 2);
        [tmp, iVertMin] = min(d2);
        % Get connectivity matrix around the electrodes
        VertConn = (GL > 0);
        iVertFar = find(d2 > SizeHorizon .^ 2);
        VertConn(iVertFar,:) = 0;
        VertConn(:,iVertFar) = 0;
        % Propagate connections
        VertConn = (VertConn ^ 20);
        % Get vertices in the neighborhood of each vertex
        Index{iChan} = find(VertConn(iVertMin,:));
        Distance{iChan} = sqrt(d2(Index{iChan})');
    end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    % Create data directory into which converted data goes
    [P, F] = fileparts(spm_str_manip(Fname(k, :), 'r'));
    if ~isempty(P)
        [m, sta] = mkdir(P, spm_str_manip(Fname(k, :), 'tr'));
    else
        mkdir(spm_str_manip(Fname(k, :), 'tr'));
    end
    cd(fullfile(P, F));

    % Create one volume for each time bin
    maxTime = round(1000*max(abs(time(timewindow))));
    for j = timewindow
        win = j + (-timewindowwidth:timewindowwidth);
        win = win((win >= 1) & (win <= D.nsamples));
        tmpd = mean(D(iGood,win,:), 2);

        EMap = zeros(length(GL),1);
        EMapDist = zeros(length(GL),1);
        for i1 = 1:length(iGood)
            if isnan(tmpd(i1))
                map = EMapDist(Index{iGood(i1)});
                mapZero = find(map==0);
                EMap(Index{iGood(i1)}(mapZero)) = NaN;
            else
                map = EMap(Index{iGood(i1)});
                mapNoNaN = find(~isnan(map));
                mapNaN = find(isnan(map));
                EMap(Index{iGood(i1)}(mapNoNaN)) = EMap(Index{iGood(i1)}(mapNoNaN))+tmpd(i1)*(SizeHorizon-Distance{iGood(i1)}(mapNoNaN))';
                EMapDist(Index{iGood(i1)}(mapNoNaN)) = EMapDist(Index{iGood(i1)}(mapNoNaN))+SizeHorizon-Distance{iGood(i1)}(mapNoNaN)';
                EMap(Index{iGood(i1)}(mapNaN)) = tmpd(i1)*(SizeHorizon-Distance{iGood(i1)}(mapNaN))';
                EMapDist(Index{iGood(i1)}(mapNaN)) = SizeHorizon-Distance{iGood(i1)}(mapNaN)';
            end
        end
        % Normalize map with distance (set to 0 vertices with no values, instead of NaN)
        I = (EMapDist > 0);
        EMap(I) = EMap(I) ./ EMapDist(I);
        
        % Smooth surface maps
        if (SmoothIterations > 0)
            EMap = spm_mesh_smooth(GL, EMap, SmoothIterations);
            % Remove all the values that were not initially defined
            EMap(~I) = 0;
        end

        % Output file name
        J = round(1000*time(j));
        if (maxTime < 1e1)
            outFile = sprintf('sample_%d.gii', J);
        elseif (maxTime < 1e2)
            outFile = sprintf('sample_%0.2d.gii', J);
        elseif (maxTime < 1e3)
            outFile = sprintf('sample_%0.3d.gii', J);
        elseif (maxTime < 1e4)
            outFile = sprintf('sample_%0.4d.gii', J);
        elseif (maxTime < 1e5)
            outFile = sprintf('sample_%0.5d.gii', J);
        elseif (maxTime < 1e6)
            outFile = sprintf('sample_%0.6d.gii', J);
        else
            outFile = sprintf('sample_%d.gii', J);            
        end
        % Save .gii file
        out_spm_gii(MeshFile, outFile, EMap);
        % Return output file
        OutputFiles{end+1} = fullfile(pwd, outFile);
        
        disp(sprintf('File #%d, time #%d', k, J));
    end

    cd ..
end

spm('Pointer', 'Arrow');


