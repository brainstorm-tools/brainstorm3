function [ hContactFig ] = view_contactsheet( hFig, inctype, orientation, OutputFile, nImages, TimeRange, SkipVolume )
% VIEW_CONTACTSHEET: Display many slices of a MRI or a figure in the same image.
% 
% USAGE:  hContactFig = view_contactsheet( hFig, inctype, orientation)
%         hContactFig = view_contactsheet( hFig, inctype, orientation, OutputFile )
%         hContactFig = view_contactsheet( hFig, inctype, orientation, OutputFile, nImages, TimeRange )
%
% INPUT: 
%     - hFig        : handle to Matlab figure to export
%     - inctype     : Incrementation type, {'volume', 'time', 'freq'}
%     - orientation : {'x','y','z','fig'} axis of the cuts; 'fig' gets the entire figure
%     - OutputFile  : full path to a default file or directory to save the contact sheet image.
%     - nImages     : number of slices in the contact sheet (default: 20)
%     - TimeRange   : [tStart,tStop], time window to extract (all time definition if not specified)
%     - SkipVolume  : Percent of the volume to skip on each side (value must be between 0 and .4)
% OUTPUT:
%     - hContactFig : handle to the figure where the contact sheet image is displayed

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
% Authors: Francois Tadel, 2008-2016

global GlobalData;

%% ===== PARSE INPUTS =====
if (nargin < 4)
    OutputFile = [];
end
if (nargin < 5)
    nImages = [];
end
if (nargin < 6)
    TimeRange = [];
end
if (nargin < 7)
    SkipVolume = [];
end

%% ===== OUTPUT FILE =====
% Default extension
DefaultFormats = bst_get('DefaultFormats');
if isempty(DefaultFormats.ImageOut)
    fExt = 'tif';
else
    fExt = lower(DefaultFormats.ImageOut);
end
% Default file name
isAutoSave = 0;
if isempty(OutputFile)
    OutputFile = ['contact_sheet.' fExt];
elseif isdir(OutputFile)
    OutputFile = bst_fullfile(OutputFile, ['contact_sheet.' fExt]);
else
    isAutoSave = 1;
end


%% ===== GET TIME/VOLUME =====    
% Get default values for the number of images
ContactSheetOptions = bst_get('ContactSheetOptions');
% Get dimension
switch lower(orientation)
    case 'fig',  dim = 0;
    case 'x',    dim = 1;
    case 'y',    dim = 2;
    case 'z',    dim = 3;
end
% Time / volume / freq
switch lower(inctype)
    case 'time'
        % Get figure description
        [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);
        % Get time vector for this Dataset
        TimeVector = bst_memory('GetTimeVector', iDS, [], 'UserTimeWindow');

        % ===== CONTACT SHEET OPTIONS =====
        if isempty(TimeRange) || isempty(nImages)
            % Get default values for the number of images
            TimeRange = ContactSheetOptions.TimeRange;
            if isempty(TimeRange) || any(TimeRange < TimeVector(1)) || any(TimeRange > TimeVector(end))
                TimeRange = TimeVector([1 end]);
            end
            % Time units
            if (max(abs(TimeRange)) > 2)
                TimeUnit = 's';
                TimeFormat = '%1.4f';
            else
                TimeRange = TimeRange * 1000;
                TimeUnit = 'ms';
                TimeFormat = '%1.2f';
            end
            % Ask user the number of snapshots to take if it is not specified in command line
            res = java_dialog('input', {['Start time (' TimeUnit '):'], ['Stop time (' TimeUnit '):'], 'Number of snapshots:'}, 'Contact sheet', [], ...
                                       {num2str(TimeRange(1),TimeFormat), num2str(TimeRange(2),TimeFormat), num2str(ContactSheetOptions.nImages)});
            if isempty(res) || isempty(str2num(res{1})) || isempty(str2num(res{2})) || isempty(str2num(res{3}))
                return
            end
            TimeRange = [str2num(res{1}), str2num(res{2})];
            nImages = str2num(res{3});
            % Time units
            if strcmpi(TimeUnit, 'ms')
                TimeRange = TimeRange / 1000;
            end
            ContactSheetOptions.TimeRange = TimeRange;
        end
        % =================================
        
        % Time range
        TimeRange(1) = max(TimeRange(1), TimeVector(1));
        TimeRange(2) = min(TimeRange(2), TimeVector(end));
        if (TimeRange(1) >= TimeRange(2))
            error('Invalid time range.');
        end
        % Get current time
        initPos = GlobalData.UserTimeWindow.CurrentTime;
        % Create the contact sheet time vector
        Samples = TimeVector(bst_closest(linspace(TimeRange(1), TimeRange(2), nImages), TimeVector));
        % If reading MRI slices: need to get the surface definition
        if (dim ~= 0)
            [img, TessInfo, iTess] = GetImage(hFig, dim);
        end
        % Do not use progress bar
        isProgress = 0;
        
    case 'freq'
        % Get frequency vector
        if iscell(GlobalData.UserFrequencies.Freqs)
            BandBounds = process_tf_bands('GetBounds', GlobalData.UserFrequencies.Freqs);
            FreqVector = mean(BandBounds,2);
            FreqLabels = GlobalData.UserFrequencies.Freqs(:,1);
        else
            FreqVector = GlobalData.UserFrequencies.Freqs;
            FreqLabels = {};
            for i = 1:length(FreqVector)
                FreqLabels{i} = sprintf('%g Hz', round(FreqVector(i) * 100) ./ 100);
            end
        end
        % Plotting all the frequencies
        nImages = length(FreqVector);
        % Get current time
        initPos = GlobalData.UserFrequencies.iCurrentFreq;
        % If reading MRI slices: need to get the surface definition
        if (dim ~= 0)
            [img, TessInfo, iTess] = GetImage(hFig, dim);
        end
        % Do not use progress bar
        isProgress = 0;
        
    case 'volume'
        % ===== CONTACT SHEET OPTIONS =====
        if isempty(nImages) || isempty(SkipVolume)
            % Ask user the number of snapshots to take if it is not specified in command line
            res = java_dialog('input', {'Number of snapshots:', 'Percent of volume to skip:'}, 'Contact sheet', [], ...
                                           {num2str(ContactSheetOptions.nImages), sprintf('%d', round(ContactSheetOptions.SkipVolume*100))});
            if isempty(res) || isempty(str2num(res{1})) || isempty(str2num(res{2}))
                return
            end
            nImages = str2num(res{1});
            SkipVolume = bst_saturate(str2num(res{2}), [0,100]) ./ 100;
            ContactSheetOptions.SkipVolume = SkipVolume;
        end
        % =================================
        % Surface information
        [img, TessInfo, iTess] = GetImage(hFig, dim);
        initPos = TessInfo(iTess).CutsPosition;
        % Get slices positions
        sMri = bst_memory('GetMri', TessInfo(iTess).SurfaceFile);
        mriSize = size(sMri.Cube, dim);
        Samples = floor(linspace(max(1,SkipVolume*mriSize), (1-SkipVolume)*mriSize, nImages));
        if (dim == 2) || (dim == 3)
            Samples = bst_flip(Samples,2);
        end
        % Use progress bar
        isProgress = 1;
end
% Save new values to preferences
if ismember(inctype, {'time', 'volume'})
    ContactSheetOptions.nImages = nImages;
    bst_set('ContactSheetOptions', ContactSheetOptions);
end
% Get MRI display options
MriOptions = bst_get('MriOptions');


%% ===== BUILD IMAGE =====
% Progress bar
if isProgress
    bst_progress('start', 'Contact sheet: axial slice', 'Getting slices...', 0, nImages);
end
% Get test image, to build the output volume
testImg = GetImage(hFig, dim);
% Get extracted image size
H = size(testImg, 1);
W = size(testImg, 2);
% Get number of column and rows of the contact sheet
nbRows = floor(sqrt(nImages));
nbCols = ceil(nImages / nbRows);
% Initialize final image
ImgSheet   = zeros(nbRows * H, nbCols * W, 3, class(testImg));
AlphaSheet = zeros(nbRows * H, nbCols * W);
% For each time instant
for iSample = 1:nImages
    % Progress bar
    if isProgress
        bst_progress('inc', 1);
    end
    % Next sample
    switch lower(inctype)
        case 'time'
            % Set time
            panel_time('SetCurrentTime', Samples(iSample));
            drawnow;
        case 'freq'
            % Set frequency
            panel_freq('SetCurrentFreq', iSample);
            drawnow;
        case 'volume'
            % Change cut position
            slicesPos = [NaN NaN NaN];
            slicesPos(dim) = Samples(iSample);
            panel_surface('PlotMri', hFig, slicesPos);
    end
    
    % Get full figure
    if (dim == 0)
        % Screen capture
        switch lower(inctype)
            case 'time',    img = out_figure_image(hFig, [], 'time');
            case 'freq',    img = out_figure_image(hFig, [], FreqLabels{iSample});
            case 'volume',  img = out_figure_image(hFig);
        end
        alpha = ones(size(img,1), size(img,2), 1);
    % Get one slice
    else
        TessInfo = getappdata(hFig, 'Surface');
        % Get image
        img   = get(TessInfo(iTess).hPatch(dim), 'CData');
        img   = bst_flip(img, 1);
        alpha = get(TessInfo(iTess).hPatch(dim), 'AlphaData');
        alpha = bst_flip(alpha, 1);
        % Apply radiological orientation
        if MriOptions.isRadioOrient
            img   = bst_flip(img, 2);
            alpha = bst_flip(alpha, 2);
        end
    end        
    % Find extacted image position in final sheet
    i = floor((iSample-1) / nbCols);
    j = mod(iSample-1, nbCols);
    ImgSheet(i*H+1:(i+1)*H, j*W+1:(j+1)*W, :) = img;
    AlphaSheet(i*H+1:(i+1)*H, j*W+1:(j+1)*W) = alpha;
end

%% ===== RESTORE INITIAL POSITION =====
switch lower(inctype)
    case 'time'
        panel_time('SetCurrentTime', initPos);
    case 'freq'
        panel_freq('SetCurrentFreq', initPos);
    case 'volume'
        TessInfo(iTess).CutsPosition = initPos;
        setappdata(hFig, 'Surface', TessInfo);
        figure_3d('UpdateMriDisplay', hFig, dim, TessInfo, iTess);
end


%% ===== REMOVE USELESS BACKGROUND =====
% Only in the case of MRI slices
if (dim ~= 0)
    % Get background points
    background = double(AlphaSheet == 0);
    % If there are no transparent points on the surface: detect "black" points
    if (nnz(background) == 0)
        background = double(sqrt(sum(double(ImgSheet).^2,3)) < .05);
    end
    % Grow background region, to remove all the small parasites
    kernel = ones(5,5);
    background = double(conv2(background, kernel, 'same') > 0);
    % Grow foreground regions, to cut at least 10 pixels away from each meaningful block of data
    kernel = ones(11);
    background = conv2(double(background == 0), kernel, 'same') == 0;
    % Detect the empty columns and arrows
    iEmptyCol = find(all(background, 1));
    iEmptyRow = find(all(background, 2));
    % Remove empty lines and columns
    ImgSheet(iEmptyRow, :, :) = [];
    ImgSheet(:, iEmptyCol, :) = [];
end


%% ===== RE-INTERPOLATE IMAGE =====
% If the MRI image is non-isotropic, re-interpolate it according to the voxel size
if (dim ~= 0)
    % Get subject MRI
    sMri = bst_memory('GetMri', TessInfo(iTess).SurfaceFile);
    % Get image pixel size
    pixSize = sMri.Voxsize;
    pixSize(dim) = [];
    % If image is non-isotropic
    if (pixSize(1) ~= pixSize(2))
        % Expand width: Permute dimensions and expand height
        isPermute = (pixSize(1) > pixSize(2));
        if isPermute
            ImgSheet = permute(ImgSheet, [2 1 3]);
            pixSize = fliplr(pixSize);
        end
        
        % === Expand height ===
        % Get new image size
        ratio = pixSize(2) ./ pixSize(1);
        initHeight = size(ImgSheet,1);
        finalHeight = round(initHeight .* ratio);
        X  = linspace(1, finalHeight, initHeight);
        Xi = 1:finalHeight;
        % Build upsampled image
        ImgSheet_rsmp = zeros(finalHeight, size(ImgSheet,2), 3);
        for j = 1:size(ImgSheet,2)
            for k = 1:size(ImgSheet,3)
                ImgSheet_rsmp(:,j,k) = interp1(X, ImgSheet(:,j,k), Xi);
            end
        end
        ImgSheet = ImgSheet_rsmp;
        
        % Re-permute
        if isPermute
            ImgSheet = permute(ImgSheet, [2 1 3]);
        end
    end
end


%% ===== DISPLAY/SAVE IMAGE =====
% Save or display
if isAutoSave
    out_image(OutputFile, ImgSheet);
    hContactFig = [];
else
    hContactFig = view_image(ImgSheet, [], ['Contact sheet : ', get(hFig, 'Name')], OutputFile);
end
% Close progress bar
if isProgress
    bst_progress('stop');
end
end



%% ================================================================================
%  ===== GET IMAGE ================================================================
%  ================================================================================
function [img, TessInfo, iTess] = GetImage(hFig, dim)
    if (dim == 0)
        drawnow;
        figure(hFig);
        img = out_figure_image(hFig);
    else
        % Get slice in the right orientation
        TessInfo = getappdata(hFig, 'Surface');
        iTess = strcmpi('Anatomy', {TessInfo.Name});
        if isempty(iTess)
            hContactFig = [];
            return
        end
        hSlice = TessInfo(iTess).hPatch(dim);
        % Get test image, to build the output volume
        img = get(hSlice, 'CData');
    end
end


