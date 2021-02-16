function Labels = mri_getlabels_mori()
% ATLAS     : Mori 2009
% REFERENCE : https://pubmed.ncbi.nlm.nih.gov/19571751/

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
        1, 'SupParLo L',     [    0  204    0]; ...   % Left Superior Parietal Lobule
        2, 'SupParLo R',     [    0  204    0]; ...   % Right Superior Parietal Lobule
        3, 'CinGy L',        [  102  102  255]; ...   % Left Cingulate Gyrus
        4, 'CinGy R',        [  102  102  255]; ...   % Right Cingulate Gyrus
        5, 'SupFroGy L',     [    0  255  255]; ...   % Left Superior Frontal Gyrus
        6, 'SupFroGy R',     [    0  255  255]; ...   % Right Superior Frontal Gyrus
        7, 'MidFroGy L',     [  102    0    0]; ...   % Left Middle Frontal Gyrus
        8, 'MidFroGy R',     [  102    0    0]; ...   % Right Middle Frontal Gyrus
        9, 'FroGy L',        [  255  215    0]; ...   % Left Frontal Gyrus
       10, 'FroGy R',        [  255  215    0]; ...   % Right Frontal Gyrus
       11, 'PrcGy L',        [  255    0    0]; ...   % Left Precentral Gyrus
       12, 'PrcGy R',        [  255    0    0]; ...   % Right Precentral Gyrus
       13, 'PoCGy L',        [  255  177  100]; ...   % Left Postcentral Gyrus
       14, 'PoCGy R',        [  255  177  100]; ...   % Right Postcentral Gyrus
       15, 'AngGy L',        [  255    0  255]; ...   % Left Angular Gyrus
       16, 'AngGy R',        [  255    0  255]; ...   % Right Angular Gyrus
       17, 'Cun L',          [    0  102    0]; ...   % Left Cuneus
       18, 'Cun R',          [    0  102    0]; ...   % Right Cuneus
       19, 'LinGy L',        [    0  204    0]; ...   % Left Lingual Gyrus
       20, 'LinGy R',        [    0  204    0]; ...   % Right Lingual Gyrus
       21, 'FusGy L',        [  102  102  255]; ...   % Left Fusiform Gyrus
       22, 'FusGy R',        [  102  102  255]; ...   % Right Fusiform Gyrus
       23, 'ParHipGy L',     [    0  255  255]; ...   % Left Parahippocampus Gyrus
       24, 'ParHipGy R',     [    0  255  255]; ...   % Right Parahippocampus Gyrus
       25, 'SupOccGy L',     [  102    0    0]; ...   % Left Superior Occipital Gyrus
       26, 'SupOccGy R',     [  102    0    0]; ...   % Right Superior Occipital Gyrus
       27, 'OccGy L',        [  255  215    0]; ...   % Left Occipital Gyrus
       28, 'OccGy R',        [  255  215    0]; ...   % Right Occipital Gyrus
       29, 'MidOccGy L',     [  255    0    0]; ...   % Left Middle Occipital Gyrus
       30, 'MidOccGy R',     [  255    0    0]; ...   % Right Middle Occipital Gyrus
       31, 'Ent L',          [  255  177  100]; ...   % Left Entorhinal Area
       32, 'Ent R',          [  255  177  100]; ...   % Right Entorhinal Area
       33, 'SupTemGy L',     [  255    0  255]; ...   % Left Superior Temporal Gyrus
       34, 'SupTemGy R',     [  255    0  255]; ...   % Right Superior Temporal Gyrus
       35, 'TemGy L',        [    0  102    0]; ...   % Left Temporal Gyrus
       36, 'TemGy R',        [    0  102    0]; ...   % Right Temporal Gyrus
       37, 'MidTemGy L',     [    0  204    0]; ...   % Left Middle Temporal Gyrus
       38, 'MidTemGy R',     [    0  204    0]; ...   % Right Middle Temporal Gyrus
       39, 'LatOrbGy L',     [  102  102  255]; ...   % Left Lateral Orbital Gyrus
       40, 'LatOrbGy R',     [  102  102  255]; ...   % Right Lateral Orbital Gyrus
       41, 'MidOrbGy L',     [    0  255  255]; ...   % Left Middle Orbital Gyrus
       42, 'MidOrbGy R',     [    0  255  255]; ...   % Right Middle Orbital Gyrus
       43, 'SupMarGy L',     [  102    0    0]; ...   % Left Supramarginal Gyrus
       44, 'SupMarGy R',     [  102    0    0]; ...   % Right Supramarginal Gyrus
       45, 'RecGy L',        [  255  215    0]; ...   % Left Gyrus Rectus
       46, 'RecGy R',        [  255  215    0]; ...   % Right Gyrus Rectus
       47, 'Ins L',          [  255    0    0]; ...   % Left Insula
       48, 'Ins R',          [  255    0    0]; ...   % Right Insula
       49, 'Amy L',          [  255  177  100]; ...   % Left Amygdala
       50, 'Amy R',          [  255  177  100]; ...   % Right Amygdala
       51, 'Hip L',          [  255    0  255]; ...   % Left Hippocampus
       52, 'Hip R',          [  255    0  255]; ...   % Right Hippocampus
       53, 'Cbe L',          [    0  102    0]; ...   % Left Cerebellum
       54, 'Cbe R',          [    0  102    0]; ...   % Right Cerebellum
       55, 'CST L',          [    0  204    0]; ...   % Left corticospinal_tract
       56, 'CST R',          [    0  204    0]; ...   % Right corticospinal_tract
       57, 'CbePed L',       [  102  102  255]; ...   % Left Cerebellar Peduncle
       58, 'CbePed R',       [  102  102  255]; ...   % Right Cerebellar Peduncle
       59, 'MedLem L',       [    0  255  255]; ...   % Left Medial Lemniscus
       60, 'MedLem R',       [    0  255  255]; ...   % Right Medial Lemniscus
       61, 'SupCbePed L',    [  102    0    0]; ...   % Left Superior Cerebellar Peduncle
       62, 'SupCbePed R',    [  102    0    0]; ...   % Right Superior Cerebellar Peduncle
       63, 'CbrPed L',       [  255  215    0]; ...   % Left Cerebral Peduncle
       64, 'CbrPed R',       [  255  215    0]; ...   % Right Cerebral Peduncle
       65, 'AntCapLIC L',    [  255    0    0]; ...   % Left Anterior Capsule Limb of Internal
       66, 'AntCapLIC R',    [  255    0    0]; ...   % Right Anterior Capsule Limb of Internal
       67, 'PosCapLIC L',    [  255  177  100]; ...   % Left Posterior Capsule Limb of Internal
       68, 'PosCapLIC R',    [  255  177  100]; ...   % Right Posterior Capsule Limb of Internal
       69, 'PosThR L',       [  255    0  255]; ...   % Left Posterior Thalamic Radiation
       70, 'PosThR R',       [  255    0  255]; ...   % Right Posterior Thalamic Radiation
       71, 'AntCR L',        [    0  102    0]; ...   % Left Anterior Corona Radiata
       72, 'AntCR R',        [    0  102    0]; ...   % Right Anterior Corona Radiata
       73, 'SupCR L',        [    0  204    0]; ...   % Left Superior Corona Radiata
       74, 'SupCR R',        [    0  204    0]; ...   % Right Superior Corona Radiata
       75, 'PosCR L',        [  102  102  255]; ...   % Left Posterior Corona Radiata
       76, 'PosCR R',        [  102  102  255]; ...   % Right Posterior Corona Radiata
       77, 'Cin+CinGy L',    [    0  255  255]; ...   % Left Cingulate and Cingulum Gyrus
       78, 'Cin+CinGy R',    [    0  255  255]; ...   % Right Cingulate and Cingulum Gyrus
       79, 'Cin+Hip L',      [  102    0    0]; ...   % Left Cingulum and Hippocampus
       80, 'Cin+Hip R',      [  102    0    0]; ...   % Right Cingulum and Hippocampus
       81, 'ForStrTer L',    [  255  215    0]; ...   % Left Fornix Stria Terminalis
       82, 'ForStrTer R',    [  255  215    0]; ...   % Right Fornix Stria Terminalis
       83, 'SupLonLon L',    [  255    0    0]; ...   % Left Superior Longitudinal Longitudinal
       84, 'SupLonLon R',    [  255    0    0]; ...   % Right Superior Longitudinal Longitudinal
       85, 'SupOcc L',       [  255  177  100]; ...   % Left Superior Occipital
       86, 'SupOcc R',       [  255  177  100]; ...   % Right Superior Occipital
       87, 'Occ L',          [  255    0  255]; ...   % Left Occipital
       88, 'Occ R',          [  255    0  255]; ...   % Right Occipital
       89, 'SagStr L',       [    0  102    0]; ...   % Left Sagital Stratum
       90, 'SagStr R',       [    0  102    0]; ...   % Right Sagital Stratum
       91, 'CapExt L',       [    0  204    0]; ...   % Left Capsule External
       92, 'CapExt R',       [    0  204    0]; ...   % Right Capsule External
       93, 'UNC L',          [  102  102  255]; ...   % Left Uncinate
       94, 'UNC R',          [  102  102  255]; ...   % Right Uncinate
       95, 'PCT L',          [    0  255  255]; ...   % Left Pontine Crossing Tract
       96, 'PCT R',          [    0  255  255]; ...   % Right Pontine Crossing Tract
       97, 'MidCbePed L',    [  102    0    0]; ...   % Left Middle Cerebellar Peduncle
       98, 'MidCbePed R',    [  102    0    0]; ...   % Right Middle Cerebellar Peduncle
       99, 'BodForCol L',    [  255  215    0]; ...   % Left (Body) Fornix Column
      100, 'BodForCol R',    [  255  215    0]; ...   % Right (Body) Fornix Column
      101, 'CCGen L',        [  255    0    0]; ...   % Left Corpus Callosum (Genu)
      102, 'CCGen R',        [  255    0    0]; ...   % Right Corpus Callosum (Genu)
      103, 'CCBod L',        [  255  177  100]; ...   % Left Corpus Callosum (Body)
      104, 'CCBod R',        [  255  177  100]; ...   % Right Corpus Callosum (Body)
      105, 'CC L',           [  255    0  255]; ...   % Left Corpus Callosum
      106, 'CC R',           [  255    0  255]; ...   % Right Corpus Callosum
      107, 'CapRetLenINC L', [    0  102    0]; ...   % Left Capsule Retrolenticular_part_of_internal_capsule
      108, 'CapRetLenINC R', [    0  102    0]; ...   % Right Capsule Retrolenticular_part_of_internal_capsule
      109, 'RedNuc L',       [    0  204    0]; ...   % Left Red-Nucleus
      110, 'RedNuc R',       [    0  204    0]; ...   % Right Red-Nucleus
      111, 'SubNig L',       [  102  102  255]; ...   % Left Substancia-Nigra
      112, 'SubNig R',       [  102  102  255]; ...   % Right Substancia-Nigra
      113, 'Tap L',          [    0  255  255]; ...   % Left Tapatum
      114, 'Tap R',          [    0  255  255]; ...   % Right Tapatum
      115, 'CauNuc L',       [  102    0    0]; ...   % Left Caudate Nucleus
      116, 'CauNuc R',       [  102    0    0]; ...   % Right Caudate Nucleus
      117, 'Put L',          [  255  215    0]; ...   % Left Putamen
      118, 'Put R',          [  255  215    0]; ...   % Right Putamen
      119, 'Tha L',          [  255    0    0]; ...   % Left Thalamus
      120, 'Tha R',          [  255    0    0]; ...   % Right Thalamus
      121, 'GloPal L',       [  255  177  100]; ...   % Left Globus Pallidus
      122, 'GloPal R',       [  255  177  100]; ...   % Right Globus Pallidus
      123, 'MBR L',          [  255    0  255]; ...   % Left Midbrain
      124, 'MBR R',          [  255    0  255]; ...   % Right Midbrain
      125, 'PNS L',          [    0  102    0]; ...   % Left Pons
      126, 'PNS R',          [    0  102    0]; ...   % Right Pons
      127, 'MDA L',          [    0  204    0]; ...   % Left Medulla
      128, 'MDA R',          [    0  204    0]; ...   % Right Medulla
};
        