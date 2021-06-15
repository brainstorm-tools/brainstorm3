function [Histogram] = mri_histogram(volume, intensityMax, volumeType)
% MRI_HISTORGRAM: Compute, smooth and analyze the histogram of the input MRI volume.
%
% USAGE: [Histogram] = mri_histogram(volume, intensityMax, volumeType)
%        [Histogram] = mri_histogram(volume, intensityMax)
%        [Histogram] = mri_histogram(volume)
%
% INPUT:
%     - volume       : 3d-matrix, MRI volume
%     - intensityMax : Histogram upper bound (if not specified, find the global maximum of the MRI)
%     - volume type  : Indication about what is representing this volume
%                       - 'head'  : full head volume MRI
%                       - 'brain' : only the brain
%                       - 'mask'  : a binary mask (gray matter, white matter, etc.)
%                       - '' or not specified : unknown
% OUTPUT:
%     - Histogram : structure
%         |- fncY       : number of items for each intensity value
%         |- fncX       : intensity values array
%         |- cumulFncY  : integral(fncY) (cumulative fncY function, probability function)
%         |- smoothFncX : computed histogram function (x-values)
%         |- smoothFncY : computed histogram function (y-values)
%         |- max[4]     : array of the 4 most important maxima (structure)
%         |    |- x     : intensity of the given maximum
%         |    |- y     : amplitude of this maximum (number of MRI voxels with this value)
%         |    |- power : difference of this maximum and the adjacent minima
%         |- min[4]     : array of the 3 most important minima (structure)
%         |    |- x     : intensity of the given minimum
%         |    |- y     : amplitude of this minimum (number of MRI voxels with this value)
%         |    |- power : difference of this minimum and the adjacent maxima
%         |- bgLevel    : intensity value that separates the background and the objects (estimation)
%         |- whiteLevel : white matter threshold
%         |- intensityMax : maximum value in the volume

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
% Authors: Francois Tadel, 2006-2020

% Parameters
if (nargin < 2)
    intensityMax = max(volume(:));
end
if (isempty(intensityMax) || intensityMax==0)
    intensityMax = max(volume(:));
end
if (nargin < 3)
    volumeType = '';
end

% If volume contains only zeros, do not perform any histogram
if (intensityMax == 0)
    Histogram.fncX = 0;
    Histogram.fncY = numel(volume);
    Histogram.cumulFncY = Histogram.fncY;
    Histogram.smoothFncX =Histogram.fncX;
    Histogram.smoothFncY = Histogram.fncY;
    Histogram.max(1).x = Histogram.fncX;
    Histogram.max(1).y = Histogram.fncY;
    Histogram.max(1).power = Inf;
    Histogram.min = [];
    Histogram.bgLevel = 1;
    Histogram.whiteLevel = 1;
    Histogram.intensityMax = 0;
    return
end

% Histogram calculation
% Update 2021: Always forcing the use of 256 bins
bins = linspace(0, double(intensityMax), 256);
[Histogram.fncY, Histogram.fncX] = hist(volume(:), bins);
Histogram.intensityMax = intensityMax;
clear volume intensityMax;

% Cumulative Histogram
Histogram.cumulFncY = zeros(1,length(Histogram.fncY));
Histogram.cumulFncY(2:length(Histogram.fncY)) = cumsum(Histogram.fncY(2:length(Histogram.fncY)));
Histogram.cumulFncY = Histogram.cumulFncY ./ max(Histogram.cumulFncY);

% Remove all the values that are too high (99% of the values are above the threshold)
if (length(Histogram.cumulFncY) > 257)
    iCap = find(Histogram.cumulFncY > .99, 1);
    Histogram.fncX(iCap:end) = [];
    Histogram.fncY(iCap:end) = [];
    Histogram.cumulFncY(iCap:end) = [];
    Histogram.intensityMax = Histogram.fncX(end);
end

% Construct a regular Histogram function 
% Suppress all indices that has zero-values (to avoid previous normalizations)
% NOTA : Do not consider the values at the intensity value 0, it may
% not correspond to the real image Histogram...
index = find(Histogram.fncY > 10);   % PREVIOUSLY: 100 instead of 10
index = index(2:length(index));
histoX = [0 Histogram.fncX(index)];
histoY = [0 Histogram.fncY(index)];

% Smooth Histogram
% Gaussian 3 : [x(i-2) + 2x(i-1) + 4x(i) + 2x(i+1) + x(i+2)]./10
% Gaussian 5 : [x(i-3) + 2x(i-2) + 4x(i-1) + 8x(i) + 4x(i+1) + 2x(i+2) + x(i+3)]./22
N = length(histoY);
% Maxima calculation
maxIndex = find((histoY(2:N-1)>histoY(1:N-2)) & (histoY(2:N-1)>histoY(3:N))) + 1;
% Smooth while number of maxima is not < 8
i = 0;
while((length(maxIndex)>7) && (i<100))
    % Local minima/maxima calculation
    histoY(4:N-3) = (histoY(1:N-6) + 2*histoY(2:N-5) + 4*histoY(3:N-4) + 8*histoY(4:N-3) + ...
        4*histoY(5:N-2) + 2*histoY(6:N-1) + histoY(7:N))/22;
    maxIndex = find((histoY(2:N-1)>histoY(1:N-2)) & (histoY(2:N-1)>histoY(3:N))) + 1;
    i = i + 1;
end
Histogram.smoothFncX = histoX;
Histogram.smoothFncY = histoY;

% Local minima calculation
minIndex = find((histoY(2:N-1)<histoY(1:N-2)) & (histoY(2:N-1)<histoY(3:N))) + 1;
% If there are too few: compute differently
if (length(maxIndex) - length(minIndex) > 1)
    minIndex = find((histoY(2:N-1)<=histoY(1:N-2)) & (histoY(2:N-1)<=histoY(3:N))) + 1;
    minIndex(diff(minIndex) == 1) = [];
end
    
% Detect and deleting all "wrong" extrema (that are too close to each other)
epsilon = max(histoX)*.02;
i = 1;
while(i <= length(maxIndex))
    dist = Inf;
    if (i<=length(minIndex))
        % If a maximum is too close from the previous minimum (5%), delete them
        if(abs(histoX(maxIndex(i)) - histoX(minIndex(i))) < epsilon)
            dist = abs(histoX(maxIndex(i)) - histoX(minIndex(i)));
            indToDel = i;
        end
    end
    if ((i>1) && (i<=length(minIndex)+1))
        % If a maximum is too close from the next minimum (5%), delete them
        if((abs(histoX(maxIndex(i)) - histoX(minIndex(i-1))) < epsilon) && ...
                (abs(histoX(maxIndex(i)) - histoX(minIndex(i-1))) < dist))
            dist = abs(histoX(maxIndex(i)) - histoX(minIndex(i-1)));
            indToDel = i - 1;
        end
    end
    if (dist<inf)
        % Delete
        maxIndex(i) = [];
        minIndex(indToDel) = [];
    else
        i = i + 1;
    end
end
minIndex = minIndex(1:length(maxIndex)-1);

% Calculate maxima values
% If there is no max detected, returns the absolute maximum of the Histogram.
if (length(maxIndex) < 1)
    [null, maxIndex] = max(histoY);
    Histogram.max = struct('x', histoX(maxIndex(1)), 'y', histoY(maxIndex(i)), 'power', 0);
    % Else, normally extracts the maxima informations
else
    Histogram.max = repmat(struct('x', [], 'y', [], 'power', []), 1, length(maxIndex));
    for i=1:length(maxIndex)
        Histogram.max(i).x = histoX(maxIndex(i));
        Histogram.max(i).y = histoY(maxIndex(i));
        if(length(minIndex)>=1)
            % If there is at least a minimum, power = distance between
            % maximum and adjacent minima
            Histogram.max(i).power = histoY(maxIndex(i)) - (histoY(minIndex(max(1, i-1))) + histoY(minIndex(min(length(minIndex), i))))./2;
        else
            % Else power = maximum value
            Histogram.max(i).power = Histogram.max(i).x;
        end
    end
end
    
% Calculate minima values
% If there is no min detected, returns the absolute minimum of the Histogram.
if (length(minIndex) < 1)
    [null, minIndex] = min(histoY);
    Histogram.min = struct('x', histoX(minIndex(1)), 'y', histoY(minIndex(i)), 'power', 0);
    % Else, normally extracts the minima informations
else
    Histogram.min = repmat(struct('x', [], 'y', [], 'power', []), 1, length(minIndex));
    for i=1:length(minIndex)
        Histogram.min(i).x = histoX(minIndex(i));
        Histogram.min(i).y = histoY(minIndex(i));
        Histogram.min(i).power = (histoY(maxIndex(min(length(maxIndex), i))) + histoY(maxIndex(min(length(maxIndex), i+1))))./2 - histoY(minIndex(i));
    end
end

% --------------------------------------------------
% DETECTION OF VOLUME SHAPE if VOLUMETYPE == AUTO (head, brain, etc.)
%              MRI ORIENTATION    
%              GREY/WHITE/CSF LEVELS
% TODO

% Calculate the inverse function of the cumulated Histogram
% ie. with only unique values of X
[unikCumulFncY, unikCumulFncYm, unikCumulFncYn] = unique(Histogram.cumulFncY);
unikFncX = Histogram.fncX(unikCumulFncYm);

% Definition of the gray matter and white matter intensity levels
switch(volumeType)
    % Head MRI
    case {'', 'head'}
        % Default background level : fixed percentage of the cumulated Histogram
        defaultBg = round(interp1(unikCumulFncY, unikFncX, .1));
        defaultWhite = round(interp1(unikCumulFncY, unikFncX, .8));
        Histogram.bgLevel = defaultBg;
        Histogram.whiteLevel = defaultWhite;
        % Detect if the background has already been removed :
        % ie. if there is a unique 0 valued interval a the beginning of the Histogram
        % Practically : - nzero =  length of the first 0-valued interval
        %               - nnonzero = length of the first non-0-valued interval
        %               - bg removed if : (nzero > 1) and (nnonzero > nzero)
        nzero = find(Histogram.fncY(2:length(Histogram.fncY)) ~= 0);
        nnonzero = find(Histogram.fncY((nzero(1)+1):length(Histogram.fncY)) == 0);
        if ((nzero(1)>2) && ~isempty(nnonzero) && (nnonzero(1) > nzero(1)))
            Histogram.bgLevel = nzero(1);
        % Else, background has not been removed yet
        % If there is less than two maxima : use the default background threshold
        elseif (length(cat(1,Histogram.max.x)) < 2)
            Histogram.bgLevel = defaultBg;
            Histogram.whiteLevel = defaultWhite;
        % Else if there is more than one maxima :
        else
            % If the highest maxima is > (3*second highest maxima) : 
            % it is a background maxima : use the first minima after the
            % background maxima as background threshold
            % (and if this minima exist)
            [orderedMaxVal, orderedMaxInd] = sort(cat(1,Histogram.max.y), 'descend');
            if ((orderedMaxVal(1) > 3*orderedMaxVal(2)) && (length(Histogram.min) >= orderedMaxInd(1)))
                Histogram.bgLevel = Histogram.min(orderedMaxInd(1)).x;
            % Else, use the default background threshold
            else
                Histogram.bgLevel = defaultBg;
            end
        end
        
    case 'brain'
        % Determine an intensity value for the background/gray matter limit
        % and the gray matter/white matter level
        % 
        defaultBg = round(interp1(unikCumulFncY, unikFncX, .08));
        defaultWhite = round(interp1(unikCumulFncY, unikFncX, .7));
        if length(Histogram.min)<1
            Histogram.bgLevel = defaultBg;
            Histogram.whiteLevel = defaultWhite;
        else
            % Background/Grey level
            min1level = interp1(unikFncX, unikCumulFncY, Histogram.min(1).x);
            if (min1level > .15)
                Histogram.bgLevel = defaultBg;
            elseif (min1level > .5)
                Histogram.bgLevel = Histogram.min(1).x;
            elseif (length(Histogram.min) >= 2)
                min2level = interp1(unikFncX, unikCumulFncY, Histogram.min(2).x);
                if (min2level > .15 && min2level < .5)
                    Histogram.bgLevel = Histogram.min(2).x;
                else
                    Histogram.bgLevel = defaultBg;
                end
            else
                Histogram.bgLevel = defaultBg;
            end
            % Grey/White Level
            minWlevel = interp1(unikFncX, unikCumulFncY, Histogram.min(length(Histogram.min)).x);
            if (minWlevel > .8 || minWlevel < .6)
                Histogram.whiteLevel = defaultWhite;
            else
                Histogram.whiteLevel = Histogram.min(length(Histogram.min)).x;
            end
        end

    case {'mask'}
        Histogram.bgLevel = round(interp1(unikCumulFncY, unikFncX, .08));
        Histogram.whiteLevel = Histogram.fncX(length(Histogram.fncX));
        % Volume is already segmented : find the upper and lower limits in Histogram
        % Lower limit
        nzero = find(Histogram.fncY(2:length(Histogram.fncY)) ~= 0);
        nnonzero = find(Histogram.fncY((nzero(1)+1):length(Histogram.fncY)) == 0);
        if ((nzero(1)>2) && ~isempty(nnonzero) && (nnonzero(1) > nzero(1)))
            Histogram.bgLevel = nzero(1);
        end
        % Upper limit
        fnc = Histogram.fncY(length(Histogram.fncY):-1:1);
        nzero = find(2:fnc(length(Histogram.fncY)) ~= 0);
        nnonzero = find(fnc((nzero(1)+1):length(fnc)) == 0);
        if ((nzero(1)>2) && ~isempty(nnonzero) && (nnonzero(1) > nzero(1)))
            Histogram.whiteLevel = nzero(1);
        end
        
    otherwise
        % Background limit level : using the first minimum
        % (must have 60% of the values <)
        [cumulFncY, cumulFncYm, cumulFncYn] = unique(Histogram.cumulFncY);
        fncX = Histogram.fncX(cumulFncYm);
        defaultBg = interp1(cumulFncY, fncX, .55);
        if length(Histogram.min)<1
            Histogram.bgLevel = defaultBg;
        else
            min1level = interp1(fncX, cumulFncY, Histogram.min(1).x);
            if (min1level > .55)
                Histogram.bgLevel = defaultBg;
            else
                Histogram.bgLevel = Histogram.min(1).x;
            end
        end

        Histogram.whiteLevel = max(histoX);

end % --- END SWITCH ---

end


    