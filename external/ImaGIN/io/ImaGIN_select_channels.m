function [iSel, iEcg, chTags, chInd] = ImaGIN_select_channels(chNames, isSEEG)
% IMAGIN_SELECT_CHANNELS Keep only channels of interest.
%
% USAGE:  [iSel, iEcg, chTags, chInd] = ImaGIN_select_channels(chNames, isSEEG=1)
%
% INPUT: 
%    - chNames : Cell-array of strings
%    - isSEEG  : 1 if the data is SEEG, 0 if regular EEG
%
% OUTPUT:
%    - iSel   : Array of indices of the channels that are considered as valid
%    - iEcg   : Array of indices of the channels that are identified as ECG
%    - chTags : Array of electrode names for the selected sEEG channels
%    - chInd  : Array of indices of the selected contact on the corresponding sEEG electrode 

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
% Copyright (c) 2000-2019 Inserm U1216
% =============================================================================-
%
% Authors: Francois Tadel, 2017-2019

% Parse inputs
if (nargin < 2) || isempty(isSEEG)
    isSEEG = 1;
end
% Make sure the names are in one row
chNames = chNames(:)';

% Get all names: remove special characters
AllNames = cellfun(@(c)c(~ismember(c, ' .,?!-_@#$%^&*+*=()[]{}|/')), chNames, 'UniformOutput', 0);
AllTags  = cell(size(AllNames));
AllInd   = cell(size(AllNames));
isNoInd  = zeros(size(AllNames));
% Separate characters and numbers in the names
for i = 1:length(AllNames)
    % Find the last letter in the name
    iLastLetter = find(~ismember(AllNames{i}, '0123456789'), 1, 'last');
    if isempty(iLastLetter)
        iLastLetter = 0;
    end
    AllTags{i} = AllNames{i}(1:iLastLetter);
    % For EEG: The separate name/index does not make sense
    if ~isSEEG
        AllInd{i} = sprintf('%d',i);
        isNoInd(i) = 0;
    % If there are digits at the end of the name: use them as the index of the contact
    elseif (iLastLetter < length(AllNames{i}))
        AllInd{i} = AllNames{i}(iLastLetter+1:end);
    else
        isNoInd(i) = 1;
        AllInd{i} = '0';
    end
end
% Convert indices to double values
AllInd = cellfun(@str2num, AllInd);
    
% Remove all channels with indices > 18 (this is not SEEG)
% Tolerance for indices 101-118 and 201-218 (examples: electrode "T1" contact "11" => "T11",  electrode "T1" contact "2" => "T12" or "T02")
MAX_CONTACTS = 18;
if isSEEG
    uniqueTags = unique(upper(AllTags));
    for iTag = 1:length(uniqueTags)
        % Get channels of this tag
        iChTag = find(strcmpi(uniqueTags{iTag}, AllTags));
        contactInd = AllInd(iChTag);
        % Reject channels "E" without rejecting "E1"
        if any(contactInd == 0) && any(contactInd > 0)
            % Remove unwanted channels
            iChTagDel = iChTag(contactInd == 0);
            AllNames(iChTagDel) = {'XXXXX'};
            AllTags(iChTagDel) = {'XXXXX'};
            % Remove from the list, so we can process the rest of the channels
            iChTag(contactInd == 0) = [];
            contactInd(contactInd == 0) = [];
        end
        % If the tag is "X": Used by Nihon Kohden for technical tracks, but can be a SEEG electrode too. Keep only indices <= 18
        if isequal(uniqueTags{iTag}, 'X')
            iChTagExtra = iChTag(contactInd > MAX_CONTACTS);
            AllNames(iChTagExtra) = {'XXXXX'};
            AllTags(iChTagExtra) = {'XXXXX'};
        % Accept if all indices < 18
        elseif all(((contactInd >= 1) & (contactInd <= MAX_CONTACTS)))
            % OK
        % Electrode names ending in "1" or "2" (two possible nameing conventions, with or without zeros)
        elseif all(((contactInd >= 11)  & (contactInd <= 19))  | ...                  % Ending in 1, without zeros:  T11..T19, T110..T118
                   ((contactInd >= 110) & (contactInd <= 100 + MAX_CONTACTS)) | ...
                   ((contactInd >= 21)  & (contactInd <= 29))  | ...                  % Ending in 2, without zeros:  T21..T29, T210..T218
                   ((contactInd >= 210) & (contactInd <= 200 + MAX_CONTACTS))) || ...
               all(((contactInd >= 101)  & (contactInd <= 100 + MAX_CONTACTS)) | ...  % Ending in 1, with zeros:  T101..T118
                   ((contactInd >= 201)  & (contactInd <= 200 + MAX_CONTACTS)))       % Ending in 2, with zeros:  T201..T218
            % All channel indices starting with 1 => Add "1" to electrode name
            iElec1 = iChTag(((contactInd >= 11) & (contactInd <= 19))  |  (contactInd >= 101) & (contactInd <= 100 + MAX_CONTACTS));
            for i = 1:length(iElec1)
                AllTags{iElec1(i)} = [AllTags{iElec1(i)}, '1'];
                if (AllInd(iElec1(i)) < 100)
                    AllInd(iElec1(i)) = AllInd(iElec1(i)) - 10;
                elseif (AllInd(iElec1(i)) > 100)
                    AllInd(iElec1(i)) = AllInd(iElec1(i)) - 100;
                end
            end
            % All channel indices starting with 2 => Add "2" to electrode name
            iElec2 = iChTag(((contactInd >= 21) & (contactInd <= 29))  |  (contactInd >= 201) & (contactInd <= 200 + MAX_CONTACTS));
            for i = 1:length(iElec2)
                AllTags{iElec2(i)} = [AllTags{iElec2(i)}, '2'];
                if (AllInd(iElec2(i)) < 200)
                    AllInd(iElec2(i)) = AllInd(iElec2(i)) - 20;
                elseif (AllInd(iElec2(i)) > 200)
                    AllInd(iElec2(i)) = AllInd(iElec2(i)) - 200;
                end
            end
        % Mark as bad all the other channels with Label+Index (but not the channels without labels, because we want to keep the ECG)
        elseif all(contactInd > 0)
            AllNames(iChTag) = {'XXXXX'};
            AllTags(iChTag) = {'XXXXX'};
        end
        % Removed: ((length(iChTag) < 2) && ~any(chNames{iChTag(1)} == '-'))   % less than 2 (but only if not designating a bipolar montage, with '-' in the name) 
        % Keep electrodes with one contact only
    end
end

% Process all the channels
iSel = [];
iEcg = [];
for i = 1:length(AllNames)
    % ECG: Accept (should be labelled as such)
    if ismember(lower(AllTags{i}), {'ecg', 'ekg'}) || ~isempty(strfind(lower(AllNames{i}), 'ecg')) || ~isempty(strfind(lower(AllNames{i}), 'ekg'))
        iEcg(end+1) = i;
    % No index or does not end with a digit
    elseif isSEEG && (isNoInd(i) || ~ismember(AllNames{i}(end), '0123456789'))
        continue;
    % Does not contain at least a letter
    elseif isSEEG && ~any(ismember(lower(AllNames{i}), 'abcdefghijklmnopqrstuvwxyz'))
        continue;
    % Contains a /: exclude
    elseif isSEEG && any(ismember(lower(chNames{i}), '/'))
        continue;
    % Unwanted labels (strict)
    elseif ismember(lower(AllTags{i}), {'xxxxx', 'mark', 'dc', 'veo', 'heo', 'dd', 'dg', 'el', 'pulse', 'spo2', 'lpar', 'rpar', 'tib'})
        % MAYBE ADD 'oc' ??
        continue;
    % Unwanted labels (including variants): EOG, EMG, MYO, MAST, REF
    elseif ~isempty(strfind(lower(AllTags{i}), 'eog')) ...
        || ~isempty(strfind(lower(AllTags{i}), 'emg')) ...
        || ~isempty(strfind(lower(AllTags{i}), 'myo')) ...
        || ~isempty(strfind(lower(AllTags{i}), 'mast')) ...
        || ~isempty(strfind(lower(AllTags{i}), 'ref'))
        continue;
    % Unwanted EEG labels
    elseif isSEEG && ismember(lower(AllTags{i}), {'cz', 'fz', 'pz', 'oz', 'nz', 'fpz'})
        continue;
    % Unwanted electrodes that are explicitely scalp electrodes (case sensitive)
    elseif isSEEG && ismember(AllNames{i}, {'sFp1','sFp2','sF4','sF3','sC3','sC4','sP4','sP3','sO2','sO1','sF8','sF7','sT8/T4','sT7/T3','sP8/T6','sP7/T5','sPz','sFz','sIO1','sIO2','sAF9','sAF10','sF9','sF10','sCB1','sCB2','sTP7','sTP9','sTP10','sTP8','sOz','sIz','sPO4','sPO3','sCP5','sCP6','sCP1','sCP2','sFT9','sFT10','sFC2','sFC1','sAF3','sAF4','sFC6','sFC5','sCPz','sP1','sPOz','sP2','sP6','sC6','sP5','sC1','sC2','sC5','sF2','sF6','sF1','sAF8','sF5','sAF7','sFpz','sFCz','sCz'})
        continue;
    % Unwanted FPx/Fx/Cx/Tx/Pz/Ox labels
    elseif isSEEG && ismember(lower(AllNames{i}), {'fp1','fp2'}) && ~any(ismember({'fp3','fp4','fp5','fp6','fp9','fp10','fp11','fp12','fp13','fp14','fp15','fp16','fp17','fp18'}, lower(AllNames)))
        continue;
    elseif isSEEG && ismember(lower(AllNames{i}), {'f3','f4','f7','f8'}) && ~any(ismember({'f1','f2','f5','f6','f9','f10','f11','f12','f13','f14','f15','f16','f17','f18'}, lower(AllNames)))
        continue;
    elseif isSEEG && ismember(lower(AllNames{i}), {'ft1','ft2','ft9','ft10'}) && ~any(ismember({'ft5','ft6','ft11','ft12','ft13','ft14','ft15','ft16','ft17','ft18'}, lower(AllNames)))
        continue;
    elseif isSEEG && ismember(lower(AllNames{i}), {'tp9','tp10'}) && ~any(ismember({'tp1','tp2','tp5','tp6','tp11','tp12','tp13','tp14','tp15','tp16','tp17','tp18'}, lower(AllNames)))
        continue;
    elseif isSEEG && ismember(lower(AllNames{i}), {'c3','c4'}) && ~any(ismember({'c1','c2','c5','c6','c7','c8','c9','c10','c11','c12','c13','c14','c15','c16','c17','c18'}, lower(AllNames)))
        continue;
    elseif isSEEG && ismember(lower(AllNames{i}), {'t3','t4','t5','t6','t9','t10'}) && ~any(ismember({'t1','t2','t7','t8','t11','t12','t13','t14','t15','t16','t17','t18'}, lower(AllNames)))
        continue;
    elseif isSEEG && ismember(lower(AllNames{i}), {'p3','p4'}) && ~any(ismember({'p1','p2','p5','p6','p7','p8','p9','p10','p11','p12','p13','p14','p15','p16','p17','p18'}, lower(AllNames)))
        continue;
    elseif isSEEG && ismember(lower(AllNames{i}), {'o1','o2'}) && ~any(ismember({'o3','o4','o4','o5','o6','o7','o8','o9','o10','o11','o12','o13','o14','o15','o16','o17','o18'}, lower(AllNames)))
        continue;
    % Otherwise: accept
    else
        iSel(end+1) = i;
    end
end

% Sort channels by tag and index
AllTags = AllTags(iSel);
AllInd = AllInd(iSel);
uniqueTags = unique(upper(AllTags));
iOrderSel = [];
for iTag = 1:length(uniqueTags)
    iChTag = find(strcmpi(AllTags, uniqueTags{iTag}));
    [tmp, iOrderInd] = sort(AllInd(iChTag));
    iOrderSel = [iOrderSel, iChTag(iOrderInd)];
end

% Add ECG channels at the end of the file
iSel = [iSel(iOrderSel), iEcg];

% Return lists of selected channels and electrode names
chTags = AllTags;
chInd = AllInd;
