function [Mod, DispMod] = channel_get_modalities(Channel)
% CHANNEL_GET_MODALITIES: Get the list of modalities in a channel structure.

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
% Authors: Francois Tadel, 2008-2011

% ===== ALL MODALITIES =====
% Get all the sensor types
Mod = setdiff(unique({Channel.Type}), {''});
% If 'MEG MAG' and 'MEG GRAD' both available => add a 'MEG' modality
if all(ismember({'MEG MAG', 'MEG GRAD'}, Mod))
    Mod = union(Mod, 'MEG');
% Else: If only 'MEG MAG' OR 'MEG GRAD' => keep only 'MEG' modality
elseif any(ismember({'MEG MAG', 'MEG GRAD'}, Mod))
    Mod = setdiff(Mod, {'MEG MAG', 'MEG GRAD'});
    Mod = union(Mod, 'MEG');
end
% Sort modalities alphabetically
Mod = sort(Mod);

% ===== DISPLAYABLE MODALITIES =====
% Get displayable sensor type
iNonZeroLoc = find(cell2mat(cellfun(@(c)any(c(:)~=0), {Channel.Loc}, 'UniformOutput', 0)));
% Get all the sensor types
DispMod = setdiff(unique({Channel(iNonZeroLoc).Type}), {'', 'EEG REF', 'MEG REF', 'Fiducial'});
% If 'MEG MAG' and 'MEG GRAD' both available => add a 'MEG' modality
if all(ismember({'MEG MAG', 'MEG GRAD'}, DispMod))
    DispMod = union(DispMod, 'MEG');
% Else: If only 'MEG MAG' OR 'MEG GRAD' => keep only 'MEG' modality
elseif any(ismember({'MEG MAG', 'MEG GRAD'}, DispMod))
    DispMod = setdiff(DispMod, {'MEG MAG', 'MEG GRAD'});
    DispMod = union(DispMod, 'MEG');
end
% Sort modalities alphabetically
DispMod = sort(DispMod);




