function Labels = mri_getlabels_neuromorpho()
% ATLAS     : MICCAI 2012 Multi-Atlas Labeling Workshop and Challenge (Neuromorphometrics)
% REFERENCE : http://www.neuromorphometrics.com/

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
        1, '3thVen L',       [    0  204    0]; ...   % Left 3rd Ventricle
        2, '3thVen R',       [    0  204    0]; ...   % Right 3rd Ventricle
        3, '4thVen L',       [  102  102  255]; ...   % Left 4th Ventricle
        4, '4thVen R',       [  102  102  255]; ...   % Right 4th Ventricle
        5, 'Acc L',          [    0  255  255]; ...   % Left Accumbens
        6, 'Acc R',          [    0  255  255]; ...   % Right Accumbens
        7, 'Amy L',          [  102    0    0]; ...   % Left Amygdala
        8, 'Amy R',          [  102    0    0]; ...   % Right Amygdala
        9, 'Bst L',          [  255  215    0]; ...   % Left Brainstem
       10, 'Bst R',          [  255  215    0]; ...   % Right Brainstem
       11, 'Cau L',          [  255    0    0]; ...   % Left Caudate
       12, 'Cau R',          [  255    0    0]; ...   % Right Caudate
       13, 'ExtCbe L',       [  255  177  100]; ...   % Left Cerebellum Exterior
       14, 'ExtCbe R',       [  255  177  100]; ...   % Right Cerebellum Exterior
       15, 'CbeWM L',        [  255    0  255]; ...   % Left Cerebellum White Matter
       16, 'CbeWM R',        [  255    0  255]; ...   % Right Cerebellum White Matter
       17, 'CbrWM L',        [    0  102    0]; ...   % Left Cerebral White Matter
       18, 'CbrWM R',        [    0  102    0]; ...   % Right Cerebral White Matter
       19, 'CSF L',          [    0  204    0]; ...   % Left CSF
       20, 'CSF R',          [    0  204    0]; ...   % Right CSF
       21, 'Hip L',          [  102  102  255]; ...   % Left Hippocampus
       22, 'Hip R',          [  102  102  255]; ...   % Right Hippocampus
       23, 'InfLatVen L',    [    0  255  255]; ...   % Left Inferior Lateral Ventricle
       24, 'InfLatVen R',    [    0  255  255]; ...   % Right Inferior Lateral Ventricle
       25, 'LatVen L',       [  102    0    0]; ...   % Left Lateral Ventricle
       26, 'LatVen R',       [  102    0    0]; ...   % Right Lateral Ventricle
       27, 'Pal L',          [  255  215    0]; ...   % Left Pallidum
       28, 'Pal R',          [  255  215    0]; ...   % Right Pallidum
       29, 'Put L',          [  255    0    0]; ...   % Left Putamen
       30, 'Put R',          [  255    0    0]; ...   % Right Putamen
       31, 'ThaPro L',       [  255  177  100]; ...   % Left Thalamus Proper
       32, 'ThaPro R',       [  255  177  100]; ...   % Right Thalamus Proper
       33, 'VenVen L',       [  255    0  255]; ...   % Left Ventral DC
       34, 'VenVen R',       [  255    0  255]; ...   % Right Ventral DC
       35, 'OC L',           [    0  102    0]; ...   % Left Optic Chiasm
       36, 'OC R',           [    0  102    0]; ...   % Right Optic Chiasm
       37, 'CbeLoCbe1-5 L',  [    0  204    0]; ...   % Left Cerebellar Vermal Lobules I-V
       38, 'CbeLoCbe1-5 R',  [    0  204    0]; ...   % Right Cerebellar Vermal Lobules I-V
       39, 'CbeLoCbe6-7 L',  [  102  102  255]; ...   % Left Cerebellar Vermal Lobules VI-VII
       40, 'CbeLoCbe6-7 R',  [  102  102  255]; ...   % Right Cerebellar Vermal Lobules VI-VII
       41, 'CbeLoCbe8-10 L', [    0  255  255]; ...   % Left Cerebellar Vermal Lobules VIII-X
       42, 'CbeLoCbe8-10 R', [    0  255  255]; ...   % Right Cerebellar Vermal Lobules VIII-X
       43, 'BasCbr+FobBr L', [  102    0    0]; ...   % Left Basal Forebrain
       44, 'BasCbr+FobBr R', [  102    0    0]; ...   % Right Basal Forebrain
       45, 'AntCinGy L',     [  255  215    0]; ...   % Left Anterior Cingulate Gyrus
       46, 'AntCinGy R',     [  255  215    0]; ...   % Right Anterior Cingulate Gyrus
       47, 'AntIns L',       [  255    0    0]; ...   % Left Anterior Insula
       48, 'AntIns R',       [  255    0    0]; ...   % Right Anterior Insula
       49, 'AntOrbGy L',     [  255  177  100]; ...   % Left Anterior Orbital Gyrus
       50, 'AntOrbGy R',     [  255  177  100]; ...   % Right Anterior Orbital Gyrus
       51, 'AngGy L',        [  255    0  255]; ...   % Left Angular Gyrus
       52, 'AngGy R',        [  255    0  255]; ...   % Right Angular Gyrus
       53, 'Cal+Cbr L',      [    0  102    0]; ...   % Left Calcarine Cortex
       54, 'Cal+Cbr R',      [    0  102    0]; ...   % Right Calcarine Cortex
       55, 'CenOpe L',       [    0  204    0]; ...   % Left Central Operculum
       56, 'CenOpe R',       [    0  204    0]; ...   % Right Central Operculum
       57, 'Cun L',          [  102  102  255]; ...   % Left Cuneus
       58, 'Cun R',          [  102  102  255]; ...   % Right Cuneus
       59, 'Ent L',          [    0  255  255]; ...   % Left Entorhinal Area
       60, 'Ent R',          [    0  255  255]; ...   % Right Entorhinal Area
       61, 'FroOpe L',       [  102    0    0]; ...   % Left Frontal Operculum
       62, 'FroOpe R',       [  102    0    0]; ...   % Right Frontal Operculum
       63, 'FroPo L',        [  255  215    0]; ...   % Left Frontal Pole
       64, 'FroPo R',        [  255  215    0]; ...   % Right Frontal Pole
       65, 'FusGy L',        [  255    0    0]; ...   % Left Fusiform Gyrus
       66, 'FusGy R',        [  255    0    0]; ...   % Right Fusiform Gyrus
       67, 'RecGy L',        [  255  177  100]; ...   % Left Gyrus Rectus
       68, 'RecGy R',        [  255  177  100]; ...   % Right Gyrus Rectus
       69, 'InfOccGy L',     [  255    0  255]; ...   % Left Inferior Occipital Gyrus
       70, 'InfOccGy R',     [  255    0  255]; ...   % Right Inferior Occipital Gyrus
       71, 'InfTemGy L',     [    0  102    0]; ...   % Left Inferior Temporal Gyrus
       72, 'InfTemGy R',     [    0  102    0]; ...   % Right Inferior Temporal Gyrus
       73, 'LinGy L',        [    0  204    0]; ...   % Left Lingual Gyrus
       74, 'LinGy R',        [    0  204    0]; ...   % Right Lingual Gyrus
       75, 'LatOrbGy L',     [  102  102  255]; ...   % Left Lateral Orbital Gyrus
       76, 'LatOrbGy R',     [  102  102  255]; ...   % Right Lateral Orbital Gyrus
       77, 'MidCinGy L',     [    0  255  255]; ...   % Left Middle Cingulate Gyrus
       78, 'MidCinGy R',     [    0  255  255]; ...   % Right Middle Cingulate Gyrus
       79, 'MedFroCbr L',    [  102    0    0]; ...   % Left Medial Frontal Cortex
       80, 'MedFroCbr R',    [  102    0    0]; ...   % Right Medial Frontal Cortex
       81, 'MidFroGy L',     [  255  215    0]; ...   % Left Middle Frontal Gyrus
       82, 'MidFroGy R',     [  255  215    0]; ...   % Right Middle Frontal Gyrus
       83, 'MidOccGy L',     [  255    0    0]; ...   % Left Middle Occipital Gyrus
       84, 'MidOccGy R',     [  255    0    0]; ...   % Right Middle Occipital Gyrus
       85, 'MedOrbGy L',     [  255  177  100]; ...   % Left Medial Orbital Gyrus
       86, 'MedOrbGy R',     [  255  177  100]; ...   % Right Medial Orbital Gyrus
       87, 'MedPoCGy L',     [  255    0  255]; ...   % Left Postcentral Gyrus Medial Segment
       88, 'MedPoCGy R',     [  255    0  255]; ...   % Right Postcentral Gyrus Medial Segment
       89, 'MedPrcGy L',     [    0  102    0]; ...   % Left Precentral Gyrus Medial Segment
       90, 'MedPrcGy R',     [    0  102    0]; ...   % Right Precentral Gyrus Medial Segment
       91, 'SupMedFroGy L',  [    0  204    0]; ...   % Left Superior Frontal Gyrus Medial Segment
       92, 'SupMedFroGy R',  [    0  204    0]; ...   % Right Superior Frontal Gyrus Medial Segment
       93, 'MidTemGy L',     [  102  102  255]; ...   % Left Middle Temporal Gyrus
       94, 'MidTemGy R',     [  102  102  255]; ...   % Right Middle Temporal Gyrus
       95, 'OccPo L',        [    0  255  255]; ...   % Left Occipital Pole
       96, 'OccPo R',        [    0  255  255]; ...   % Right Occipital Pole
       97, 'OccFusGy L',     [  102    0    0]; ...   % Left Occipital Fusiform Gyrus
       98, 'OccFusGy R',     [  102    0    0]; ...   % Right Occipital Fusiform Gyrus
       99, 'InfFroGy L',     [  255  215    0]; ...   % Left Opercular Part of the Inferior Frontal Gyrus
      100, 'InfFroGy R',     [  255  215    0]; ...   % Right Opercular Part of the Inferior Frontal Gyrus
      101, 'InfFroOrbGy L',  [  255    0    0]; ...   % Left Orbital Part of the Inferior Frontal Gyrus
      102, 'InfFroOrbGy R',  [  255    0    0]; ...   % Right Orbital Part of the Inferior Frontal Gyrus
      103, 'PosCinGy L',     [  255  177  100]; ...   % Left Posterior Cingulate Gyrus
      104, 'PosCinGy R',     [  255  177  100]; ...   % Right Posterior Cingulate Gyrus
      105, 'PCu L',          [  255    0  255]; ...   % Left Precuneus
      106, 'PCu R',          [  255    0  255]; ...   % Right Precuneus
      107, 'ParHipGy L',     [    0  102    0]; ...   % Left Parahippocampus Gyrus
      108, 'ParHipGy R',     [    0  102    0]; ...   % Right Parahippocampus Gyrus
      109, 'PosIns L',       [    0  204    0]; ...   % Left Posterior Insula
      110, 'PosIns R',       [    0  204    0]; ...   % Right Posterior Insula
      111, 'ParOpe L',       [  102  102  255]; ...   % Left Parietal Operculum
      112, 'ParOpe R',       [  102  102  255]; ...   % Right Parietal Operculum
      113, 'PoCGy L',        [    0  255  255]; ...   % Left Postcentral Gyrus
      114, 'PoCGy R',        [    0  255  255]; ...   % Right Postcentral Gyrus
      115, 'PosOrbGy L',     [  102    0    0]; ...   % Left Posterior Orbital Gyrus
      116, 'PosOrbGy R',     [  102    0    0]; ...   % Right Posterior Orbital Gyrus
      117, 'Pla L',          [  255  215    0]; ...   % Left Planum Polare
      118, 'Pla R',          [  255  215    0]; ...   % Right Planum Polare
      119, 'PrcGy L',        [  255    0    0]; ...   % Left Precentral Gyrus
      120, 'PrcGy R',        [  255    0    0]; ...   % Right Precentral Gyrus
      121, 'Tem L',          [  255  177  100]; ...   % Left Planum Temporale
      122, 'Tem R',          [  255  177  100]; ...   % Right Planum Temporale
      123, 'SCA L',          [  255    0  255]; ...   % Left Subcallosal Area
      124, 'SCA R',          [  255    0  255]; ...   % Right Subcallosal Area
      125, 'SupFroGy L',     [    0  102    0]; ...   % Left Superior Frontal Gyrus
      126, 'SupFroGy R',     [    0  102    0]; ...   % Right Superior Frontal Gyrus
      127, 'Cbr+Mot L',      [    0  204    0]; ...   % Left Supplementary Motor Cortex
      128, 'Cbr+Mot R',      [    0  204    0]; ...   % Right Supplementary Motor Cortex
      129, 'SupMarGy L',     [  102  102  255]; ...   % Left Supramarginal Gyrus
      130, 'SupMarGy R',     [  102  102  255]; ...   % Right Supramarginal Gyrus
      131, 'SupOccGy L',     [    0  255  255]; ...   % Left Superior Occipital Gyrus
      132, 'SupOccGy R',     [    0  255  255]; ...   % Right Superior Occipital Gyrus
      133, 'SupParLo L',     [  102    0    0]; ...   % Left Superior Parietal Lobule
      134, 'SupParLo R',     [  102    0    0]; ...   % Right Superior Parietal Lobule
      135, 'SupTemGy L',     [  255  215    0]; ...   % Left Superior Temporal Gyrus
      136, 'SupTemGy R',     [  255  215    0]; ...   % Right Superior Temporal Gyrus
      137, 'TemPo L',        [  255    0    0]; ...   % Left Temporal Pole
      138, 'TemPo R',        [  255    0    0]; ...   % Right Temporal Pole
      139, 'InfFroAngGy L',  [  255  177  100]; ...   % Left Triangular Part of the Inferior Frontal Gyrus
      140, 'InfFroAngGy R',  [  255  177  100]; ...   % Right Triangular Part of the Inferior Frontal Gyrus
      141, 'TemTraGy L',     [  255    0  255]; ...   % Left Transverse Temporal Gyrus
      142, 'TemTraGy R',     [  255    0  255]; ...   % Right Transverse Temporal Gyrus
};
  