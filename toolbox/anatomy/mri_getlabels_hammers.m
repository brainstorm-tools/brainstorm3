function Labels = mri_getlabels_hammers()
% ATLAS     : Hammersmith atlas (Hammers 2003, Gousias 2008, Faillenot 2017, Wild 2017)
% REFERENCE : http://brain-development.org/brain-atlases/adult-brain-maximum-probability-map-hammers-mith-atlas-n30r83-in-mni-space/

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
        0, 'Background',     [    0    0    0]; ...
        1, 'Hip L',          [    0  204    0]; ...   % Left Hippocampus
        2, 'Hip R',          [    0  204    0]; ...   % Right Hippocampus
        3, 'Amy L',          [  102  102  255]; ...   % Left Amygdala
        4, 'Amy R',          [  102  102  255]; ...   % Right Amygdala
        5, 'AntMedTeLo L',   [    0  255  255]; ...   % Left Anterior Medial Temporal Lobe
        6, 'AntMedTeLo R',   [    0  255  255]; ...   % Right Anterior Medial Temporal Lobe
        7, 'AntLatTeLo L',   [  102    0    0]; ...   % Left Anterior Lateral Temporal Lobe
        8, 'AntLatTeLo R',   [  102    0    0]; ...   % Right Anterior Lateral Temporal Lobe
        9, 'Amb+ParHipGy L', [  255  215    0]; ...   % Left Ambient and Parahippocampus Gyri
       10, 'Amb+ParHipGy R', [  255  215    0]; ...   % Right Ambient and Parahippocampus Gyri
       11, 'SupTemGy L',     [  255    0    0]; ...   % Left Superior Temporal Gyrus
       12, 'SupTemGy R',     [  255    0    0]; ...   % Right Superior Temporal Gyrus
       13, 'InfMidTemGy L',  [  255  177  100]; ...   % Left Inferior Middle Temporal Gyri
       14, 'InfMidTemGy R',  [  255  177  100]; ...   % Right Inferior Middle Temporal Gyri
       15, 'FusGy L',        [  255    0  255]; ...   % Left Fusiform Gyrus
       16, 'FusGy R',        [  255    0  255]; ...   % Right Fusiform Gyrus
       17, 'Cbe L',          [    0  102    0]; ...   % Left Cerebellum
       18, 'Cbe R',          [    0  102    0]; ...   % Right Cerebellum
       19, 'Bst L',          [    0  204    0]; ...   % Left Brainstem
       20, 'Bst R',          [    0  204    0]; ...   % Right Brainstem
       21, 'Ins L',          [  102  102  255]; ...   % Left Insula
       22, 'Ins R',          [  102  102  255]; ...   % Right Insula
       23, 'LatOcLo L',      [    0  255  255]; ...   % Left Lateral Occipital Lobe
       24, 'LatOcLo R',      [    0  255  255]; ...   % Right Lateral Occipital Lobe
       25, 'AntCinGy L',     [  102    0    0]; ...   % Left Anterior Cinguli Gyrus
       26, 'AntCinGy R',     [  102    0    0]; ...   % Right Anterior Cinguli Gyrus
       27, 'PosCinGy L',     [  255  215    0]; ...   % Left Posterior Cinguli Gyrus
       28, 'PosCinGy R',     [  255  215    0]; ...   % Right Posterior Cinguli Gyrus
       29, 'MidFroGy L',     [  255    0    0]; ...   % Left Middle Frontal Gyrus
       30, 'MidFroGy R',     [  255    0    0]; ...   % Right Middle Frontal Gyrus
       31, 'PosTeLo L',      [  255  177  100]; ...   % Left Posterior Temporal Lobe
       32, 'PosTeLo R',      [  255  177  100]; ...   % Right Posterior Temporal Lobe
       33, 'InfLatPaLo L',   [  255    0  255]; ...   % Left Inferior Lateral Pariatal Lobe
       34, 'InfLatPaLo R',   [  255    0  255]; ...   % Right Inferior Lateral Pariatal Lobe
       35, 'CauNuc L',       [    0  102    0]; ...   % Left Caudate Nucleus
       36, 'CauNuc R',       [    0  102    0]; ...   % Right Caudate Nucleus
       37, 'AccNuc L',       [    0  204    0]; ...   % Left Accumbens Nucleus
       38, 'AccNuc R',       [    0  204    0]; ...   % Right Accumbens Nucleus
       39, 'Put L',          [  102  102  255]; ...   % Left Putamen
       40, 'Put R',          [  102  102  255]; ...   % Right Putamen
       41, 'Tha L',          [    0  255  255]; ...   % Left Thalamus
       42, 'Tha R',          [    0  255  255]; ...   % Right Thalamus
       43, 'Pal L',          [  102    0    0]; ...   % Left Pallidum
       44, 'Pal R',          [  102    0    0]; ...   % Right Pallidum
       45, 'CC L',           [  255  215    0]; ...   % Left Corpus Callosum
       46, 'CC R',           [  255  215    0]; ...   % Right Corpus Callosum
       47, 'LatTemVen L',    [  255    0    0]; ...   % Left Lateral Temporal Ventricle
       48, 'LatTemVen R',    [  255    0    0]; ...   % Right Lateral Temporal Ventricle
       49, '3thVen L',       [  255  177  100]; ...   % Left Third Ventricle
       50, '3thVen R',       [  255  177  100]; ...   % Right Third Ventricle
       51, 'PrcGy L',        [  255    0  255]; ...   % Left Precentral Gyrus
       52, 'PrcGy R',        [  255    0  255]; ...   % Right Precentral Gyrus
       53, 'RecGy L',        [    0  102    0]; ...   % Left Gyrus Rectus
       54, 'RecGy R',        [    0  102    0]; ...   % Right Gyrus Rectus
       55, 'OrbFroGy L',     [    0  204    0]; ...   % Left Orbito-Frontal Gyri
       56, 'OrbFroGy R',     [    0  204    0]; ...   % Right Orbito-Frontal Gyri
       57, 'InfFroGy L',     [  102  102  255]; ...   % Left Inferior Frontal Gyrus
       58, 'InfFroGy R',     [  102  102  255]; ...   % Right Inferior Frontal Gyrus
       59, 'SupFroGy L',     [    0  255  255]; ...   % Left Superior Frontal Gyrus
       60, 'SupFroGy R',     [    0  255  255]; ...   % Right Superior Frontal Gyrus
       61, 'PoCGy L',        [  102    0    0]; ...   % Left Postcentral Gyrus
       62, 'PoCGy R',        [  102    0    0]; ...   % Right Postcentral Gyrus
       63, 'SupParGy L',     [  255  215    0]; ...   % Left Superior Parietal Gyrus
       64, 'SupParGy R',     [  255  215    0]; ...   % Right Superior Parietal Gyrus
       65, 'LinGy L',        [  255    0    0]; ...   % Left Lingual Gyrus
       66, 'LinGy R',        [  255    0    0]; ...   % Right Lingual Gyrus
       67, 'Cun L',          [  255  177  100]; ...   % Left Cuneus
       68, 'Cun R',          [  255  177  100]; ...   % Right Cuneus
};
