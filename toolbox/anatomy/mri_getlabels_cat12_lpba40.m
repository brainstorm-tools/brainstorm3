function Labels = mri_getlabels_lpba40()
% ATLAS     : LONI LPBA40 atlas
% REFERENCE : https://resource.loni.usc.edu/resources/atlases-downloads/

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

Labels = {...
       0, 'Background', [    0    0    0]; ...
       21, 'SupFroG L', [    0  204    0]; ...   % Left Superior Frontal Gyrus
       22, 'SupFroG R', [    0  204    0]; ...   % Right Superior Frontal Gyrus
       23, 'MidFroG L', [  102  102  255]; ...   % Left Middle Frontal Gyrus
       24, 'MidFroG R', [  102  102  255]; ...   % Right Middle Frontal Gyrus
       25, 'InfFroG L', [    0  255  255]; ...   % Left Inferior Frontal Gyrus
       26, 'InfFroG R', [    0  255  255]; ...   % Right Inferior Frontal Gyrus
       27, 'PrcG L',    [  102    0    0]; ...   % Left Precentral Gyrus
       28, 'PrcG R',    [  102    0    0]; ...   % Right Precentral Gyrus
       29, 'MidOrbG L', [  255  215    0]; ...   % Left Middle Orbitofrontal Gyrus
       30, 'MidOrbG R', [  255  215    0]; ...   % Right Middle Orbitofrontal Gyrus
       31, 'LatOrbG L', [  255    0    0]; ...   % Left Lateral Orbitofrontal Gyrus
       32, 'LatOrbG R', [  255    0    0]; ...   % Right Lateral Orbitofrontal Gyrus
       33, 'RecG L',    [  255  177  100]; ...   % Left Gyrus Rectus
       34, 'RecG R',    [  255  177  100]; ...   % Right Gyrus Rectus
       41, 'PoCG L',    [  255    0  255]; ...   % Left Postcentral Gyrus
       42, 'PoCG R',    [  255    0  255]; ...   % Right Postcentral Gyrus
       43, 'SupParG L', [    0  102    0]; ...   % Left Superior Parietal Gyrus
       44, 'SupParG R', [    0  102    0]; ...   % Right Superior Parietal Gyrus
       45, 'SupMarG L', [    0  204    0]; ...   % Left Supramarginal Gyrus
       46, 'SupMarG R', [    0  204    0]; ...   % Right Supramarginal Gyrus
       47, 'AngG L',    [  102  102  255]; ...   % Left Angular Gyrus
       48, 'AngG R',    [  102  102  255]; ...   % Right Angular Gyrus
       49, 'PCu L',     [    0  255  255]; ...   % Left Precuneus
       50, 'PCu R',     [    0  255  255]; ...   % Right Precuneus
       61, 'SupOccG L', [  102    0    0]; ...   % Left Superior Occipital Gyrus
       62, 'SupOccG R', [  102    0    0]; ...   % Right Superior Occipital Gyrus
       63, 'MidOccG L', [  255  215    0]; ...   % Left Middle Occipital Gyrus
       64, 'MidOccG R', [  255  215    0]; ...   % Right Middle Occipital Gyrus
       65, 'InfOccG L', [  255    0    0]; ...   % Left Inferior Occipital Gyrus
       66, 'InfOccG R', [  255    0    0]; ...   % Right Inferior Occipital Gyrus
       67, 'Cun L',     [  255  177  100]; ...   % Left Cuneus
       68, 'Cun R',     [  255  177  100]; ...   % Right Cuneus
       81, 'SupTemG L', [  255    0  255]; ...   % Left Superior Temporal Gyrus
       82, 'SupTemG R', [  255    0  255]; ...   % Right Superior Temporal Gyrus
       83, 'MidTemG L', [    0  102    0]; ...   % Left Middle Temporal Gyrus
       84, 'MidTemG R', [    0  102    0]; ...   % Right Middle Temporal Gyrus
       85, 'InfTemG L', [    0  204    0]; ...   % Left Inferior Temporal Gyrus
       86, 'InfTemG R', [    0  204    0]; ...   % Right Inferior Temporal Gyrus
       87, 'ParHipG L', [  102  102  255]; ...   % Left Parahippocampal Gyrus
       88, 'ParHipG R', [  102  102  255]; ...   % Right Parahippocampal Gyrus
       89, 'LinG L',    [    0  255  255]; ...   % Left Lingual Gyrus
       90, 'LinG R',    [    0  255  255]; ...   % Right Lingual Gyrus
       91, 'FusG L',    [  102    0    0]; ...   % Left Fusiform Gyrus
       92, 'FusG R',    [  102    0    0]; ...   % Right Fusiform Gyrus
      101, 'Ins L',     [  255  215    0]; ...   % Left Insula
      102, 'Ins R',     [  255  215    0]; ...   % Right Insula
      121, 'CinG L',    [  255    0    0]; ...   % Left Cingulate Gyrus
      122, 'CinG R',    [  255    0    0]; ...   % Right Cingulate Gyrus
      161, 'Cau L',     [  255  177  100]; ...   % Left Caudate
      162, 'Cau R',     [  255  177  100]; ...   % Right Caudate
      163, 'Put L',     [  255    0  255]; ...   % Left Putamen
      164, 'Put R',     [  255    0  255]; ...   % Right Putamen
      165, 'Hip L',     [    0  102    0]; ...   % Left Hippocampus
      166, 'Hip R',     [    0  102    0]; ...   % Right Hippocampus
      181, 'CBeL',      [    0  204    0]; ...   % Bothside Cerebellar Lobe
      182, 'Bst',       [  255    0    0]; ...   % Bothside Brainstem
};
        