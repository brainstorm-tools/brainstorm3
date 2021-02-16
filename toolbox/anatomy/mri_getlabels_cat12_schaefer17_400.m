function Labels = mri_getlabels_shaeffer400()
% ATLAS     : Local-Global Parcellation of the Human Cerebral Cortex from Intrinsic Functional Connectivity MRI
% REFERENCE : https://pubmed.ncbi.nlm.nih.gov/28981612/

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
        1, 'VisCent_ExStr_1 L',        [  255    0    0]; ...   % 17Networks_LH_VisCent_ExStr_1
        2, 'VisCent_ExStr_2 L',        [  255    0    0]; ...   % 17Networks_LH_VisCent_ExStr_2
        3, 'VisCent_ExStr_3 L',        [  255    0    0]; ...   % 17Networks_LH_VisCent_ExStr_3
        4, 'VisCent_ExStr_4 L',        [  255    0    0]; ...   % 17Networks_LH_VisCent_ExStr_4
        5, 'VisCent_ExStr_5 L',        [  255    0    0]; ...   % 17Networks_LH_VisCent_ExStr_5
        6, 'VisCent_ExStr_6 L',        [  255    0    0]; ...   % 17Networks_LH_VisCent_ExStr_6
        7, 'VisCent_Striate_1 L',      [  255    0    0]; ...   % 17Networks_LH_VisCent_Striate_1
        8, 'VisCent_ExStr_7 L',        [  255    0    0]; ...   % 17Networks_LH_VisCent_ExStr_7
        9, 'VisCent_ExStr_8 L',        [  255    0    0]; ...   % 17Networks_LH_VisCent_ExStr_8
       10, 'VisCent_ExStr_9 L',        [  255    0    0]; ...   % 17Networks_LH_VisCent_ExStr_9
       11, 'VisCent_ExStr_10 L',       [  255    0    0]; ...   % 17Networks_LH_VisCent_ExStr_10
       12, 'VisCent_ExStr_11 L',       [  255    0    0]; ...   % 17Networks_LH_VisCent_ExStr_11
       13, 'VisPeri_ExStrInf_1 L',     [  102  102  255]; ...   % 17Networks_LH_VisPeri_ExStrInf_1
       14, 'VisPeri_ExStrInf_2 L',     [  102  102  255]; ...   % 17Networks_LH_VisPeri_ExStrInf_2
       15, 'VisPeri_ExStrInf_3 L',     [  102  102  255]; ...   % 17Networks_LH_VisPeri_ExStrInf_3
       16, 'VisPeri_ExStrInf_4 L',     [  102  102  255]; ...   % 17Networks_LH_VisPeri_ExStrInf_4
       17, 'VisPeri_ExStrInf_5 L',     [  102  102  255]; ...   % 17Networks_LH_VisPeri_ExStrInf_5
       18, 'VisPeri_StriCal_1 L',      [  102  102  255]; ...   % 17Networks_LH_VisPeri_StriCal_1
       19, 'VisPeri_StriCal_2 L',      [  102  102  255]; ...   % 17Networks_LH_VisPeri_StriCal_2
       20, 'VisPeri_ExStrSup_1 L',     [  102  102  255]; ...   % 17Networks_LH_VisPeri_ExStrSup_1
       21, 'VisPeri_ExStrSup_2 L',     [  102  102  255]; ...   % 17Networks_LH_VisPeri_ExStrSup_2
       22, 'VisPeri_ExStrSup_3 L',     [  102  102  255]; ...   % 17Networks_LH_VisPeri_ExStrSup_3
       23, 'VisPeri_ExStrSup_4 L',     [  102  102  255]; ...   % 17Networks_LH_VisPeri_ExStrSup_4
       24, 'VisPeri_ExStrSup_5 L',     [  102  102  255]; ...   % 17Networks_LH_VisPeri_ExStrSup_5
       25, 'SomMotA_1 L',              [  255  177  100]; ...   % 17Networks_LH_SomMotA_1
       26, 'SomMotA_2 L',              [  255  177  100]; ...   % 17Networks_LH_SomMotA_2
       27, 'SomMotA_3 L',              [  255  177  100]; ...   % 17Networks_LH_SomMotA_3
       28, 'SomMotA_4 L',              [  255  177  100]; ...   % 17Networks_LH_SomMotA_4
       29, 'SomMotA_5 L',              [  255  177  100]; ...   % 17Networks_LH_SomMotA_5
       30, 'SomMotA_6 L',              [  255  177  100]; ...   % 17Networks_LH_SomMotA_6
       31, 'SomMotA_7 L',              [  255  177  100]; ...   % 17Networks_LH_SomMotA_7
       32, 'SomMotA_8 L',              [  255  177  100]; ...   % 17Networks_LH_SomMotA_8
       33, 'SomMotA_9 L',              [  255  177  100]; ...   % 17Networks_LH_SomMotA_9
       34, 'SomMotA_10 L',             [  255  177  100]; ...   % 17Networks_LH_SomMotA_10
       35, 'SomMotA_11 L',             [  255  177  100]; ...   % 17Networks_LH_SomMotA_11
       36, 'SomMotA_12 L',             [  255  177  100]; ...   % 17Networks_LH_SomMotA_12
       37, 'SomMotA_13 L',             [  255  177  100]; ...   % 17Networks_LH_SomMotA_13
       38, 'SomMotA_14 L',             [  255  177  100]; ...   % 17Networks_LH_SomMotA_14
       39, 'SomMotA_15 L',             [  255  177  100]; ...   % 17Networks_LH_SomMotA_15
       40, 'SomMotA_16 L',             [  255  177  100]; ...   % 17Networks_LH_SomMotA_16
       41, 'SomMotA_17 L',             [  255  177  100]; ...   % 17Networks_LH_SomMotA_17
       42, 'SomMotA_18 L',             [  255  177  100]; ...   % 17Networks_LH_SomMotA_18
       43, 'SomMotA_19 L',             [  255  177  100]; ...   % 17Networks_LH_SomMotA_19
       44, 'SomMotB_Aud_1 L',          [    0  255  255]; ...   % 17Networks_LH_SomMotB_Aud_1
       45, 'SomMotB_Aud_2 L',          [    0  255  255]; ...   % 17Networks_LH_SomMotB_Aud_2
       46, 'SomMotB_Ins_1 L',          [    0  255  255]; ...   % 17Networks_LH_SomMotB_Ins_1
       47, 'SomMotB_S2_1 L',           [    0  255  255]; ...   % 17Networks_LH_SomMotB_S2_1
       48, 'SomMotB_S2_2 L',           [    0  255  255]; ...   % 17Networks_LH_SomMotB_S2_2
       49, 'SomMotB_Aud_3 L',          [    0  255  255]; ...   % 17Networks_LH_SomMotB_Aud_3
       50, 'SomMotB_Aud_4 L',          [    0  255  255]; ...   % 17Networks_LH_SomMotB_Aud_4
       51, 'SomMotB_S2_3 L',           [    0  255  255]; ...   % 17Networks_LH_SomMotB_S2_3
       52, 'SomMotB_S2_4 L',           [    0  255  255]; ...   % 17Networks_LH_SomMotB_S2_4
       53, 'SomMotB_S2_5 L',           [    0  255  255]; ...   % 17Networks_LH_SomMotB_S2_5
       54, 'SomMotB_S2_6 L',           [    0  255  255]; ...   % 17Networks_LH_SomMotB_S2_6
       55, 'SomMotB_Cent_1 L',         [    0  255  255]; ...   % 17Networks_LH_SomMotB_Cent_1
       56, 'SomMotB_Cent_2 L',         [    0  255  255]; ...   % 17Networks_LH_SomMotB_Cent_2
       57, 'SomMotB_Cent_3 L',         [    0  255  255]; ...   % 17Networks_LH_SomMotB_Cent_3
       58, 'SomMotB_Cent_4 L',         [    0  255  255]; ...   % 17Networks_LH_SomMotB_Cent_4
       59, 'SomMotB_Cent_5 L',         [    0  255  255]; ...   % 17Networks_LH_SomMotB_Cent_5
       60, 'DorsAttnA_TempOcc_1 L',    [  255    0  255]; ...   % 17Networks_LH_DorsAttnA_TempOcc_1
       61, 'DorsAttnA_TempOcc_2 L',    [  255    0  255]; ...   % 17Networks_LH_DorsAttnA_TempOcc_2
       62, 'DorsAttnA_TempOcc_3 L',    [  255    0  255]; ...   % 17Networks_LH_DorsAttnA_TempOcc_3
       63, 'DorsAttnA_TempOcc_4 L',    [  255    0  255]; ...   % 17Networks_LH_DorsAttnA_TempOcc_4
       64, 'DorsAttnA_ParOcc_1 L',     [  255    0  255]; ...   % 17Networks_LH_DorsAttnA_ParOcc_1
       65, 'DorsAttnA_ParOcc_2 L',     [  255    0  255]; ...   % 17Networks_LH_DorsAttnA_ParOcc_2
       66, 'DorsAttnA_SPL_1 L',        [  255    0  255]; ...   % 17Networks_LH_DorsAttnA_SPL_1
       67, 'DorsAttnA_SPL_2 L',        [  255    0  255]; ...   % 17Networks_LH_DorsAttnA_SPL_2
       68, 'DorsAttnA_SPL_3 L',        [  255    0  255]; ...   % 17Networks_LH_DorsAttnA_SPL_3
       69, 'DorsAttnA_SPL_4 L',        [  255    0  255]; ...   % 17Networks_LH_DorsAttnA_SPL_4
       70, 'DorsAttnA_SPL_5 L',        [  255    0  255]; ...   % 17Networks_LH_DorsAttnA_SPL_5
       71, 'DorsAttnA_SPL_6 L',        [  255    0  255]; ...   % 17Networks_LH_DorsAttnA_SPL_6
       72, 'DorsAttnA_SPL_7 L',        [  255    0  255]; ...   % 17Networks_LH_DorsAttnA_SPL_7
       73, 'DorsAttnB_PostC_1 L',      [  102    0    0]; ...   % 17Networks_LH_DorsAttnB_PostC_1
       74, 'DorsAttnB_PostC_2 L',      [  102    0    0]; ...   % 17Networks_LH_DorsAttnB_PostC_2
       75, 'DorsAttnB_PostC_3 L',      [  102    0    0]; ...   % 17Networks_LH_DorsAttnB_PostC_3
       76, 'DorsAttnB_PostC_4 L',      [  102    0    0]; ...   % 17Networks_LH_DorsAttnB_PostC_4
       77, 'DorsAttnB_PostC_5 L',      [  102    0    0]; ...   % 17Networks_LH_DorsAttnB_PostC_5
       78, 'DorsAttnB_PostC_6 L',      [  102    0    0]; ...   % 17Networks_LH_DorsAttnB_PostC_6
       79, 'DorsAttnB_PostC_7 L',      [  102    0    0]; ...   % 17Networks_LH_DorsAttnB_PostC_7
       80, 'DorsAttnB_PostC_8 L',      [  102    0    0]; ...   % 17Networks_LH_DorsAttnB_PostC_8
       81, 'DorsAttnB_PostC_9 L',      [  102    0    0]; ...   % 17Networks_LH_DorsAttnB_PostC_9
       82, 'DorsAttnB_FEF_1 L',        [  102    0    0]; ...   % 17Networks_LH_DorsAttnB_FEF_1
       83, 'DorsAttnB_FEF_2 L',        [  102    0    0]; ...   % 17Networks_LH_DorsAttnB_FEF_2
       84, 'DorsAttnB_FEF_3 L',        [  102    0    0]; ...   % 17Networks_LH_DorsAttnB_FEF_3
       85, 'DorsAttnB_PrCv_1 L',       [  102    0    0]; ...   % 17Networks_LH_DorsAttnB_PrCv_1
       86, 'SalVentAttnA_ParOper_1 L', [    0  102    0]; ...   % 17Networks_LH_SalVentAttnA_ParOper_1
       87, 'SalVentAttnA_ParOper_2 L', [    0  102    0]; ...   % 17Networks_LH_SalVentAttnA_ParOper_2
       88, 'SalVentAttnA_ParOper_3 L', [    0  102    0]; ...   % 17Networks_LH_SalVentAttnA_ParOper_3
       89, 'SalVentAttnA_Ins_1 L',     [    0  102    0]; ...   % 17Networks_LH_SalVentAttnA_Ins_1
       90, 'SalVentAttnA_Ins_2 L',     [    0  102    0]; ...   % 17Networks_LH_SalVentAttnA_Ins_2
       91, 'SalVentAttnA_Ins_3 L',     [    0  102    0]; ...   % 17Networks_LH_SalVentAttnA_Ins_3
       92, 'SalVentAttnA_Ins_4 L',     [    0  102    0]; ...   % 17Networks_LH_SalVentAttnA_Ins_4
       93, 'SalVentAttnA_FrOper_1 L',  [    0  102    0]; ...   % 17Networks_LH_SalVentAttnA_FrOper_1
       94, 'SalVentAttnA_FrOper_2 L',  [    0  102    0]; ...   % 17Networks_LH_SalVentAttnA_FrOper_2
       95, 'SalVentAttnA_ParMed_1 L',  [    0  102    0]; ...   % 17Networks_LH_SalVentAttnA_ParMed_1
       96, 'SalVentAttnA_ParMed_2 L',  [    0  102    0]; ...   % 17Networks_LH_SalVentAttnA_ParMed_2
       97, 'SalVentAttnA_ParMed_3 L',  [    0  102    0]; ...   % 17Networks_LH_SalVentAttnA_ParMed_3
       98, 'SalVentAttnA_FrMed_1 L',   [    0  102    0]; ...   % 17Networks_LH_SalVentAttnA_FrMed_1
       99, 'SalVentAttnA_FrMed_2 L',   [    0  102    0]; ...   % 17Networks_LH_SalVentAttnA_FrMed_2
      100, 'SalVentAttnA_FrMed_3 L',   [    0  102    0]; ...   % 17Networks_LH_SalVentAttnA_FrMed_3
      101, 'SalVentAttnB_PFCl_1 L',    [  255  215    0]; ...   % 17Networks_LH_SalVentAttnB_PFCl_1
      102, 'SalVentAttnB_PFCl_2 L',    [  255  215    0]; ...   % 17Networks_LH_SalVentAttnB_PFCl_2
      103, 'SalVentAttnB_PFCl_3 L',    [  255  215    0]; ...   % 17Networks_LH_SalVentAttnB_PFCl_3
      104, 'SalVentAttnB_Ins_1 L',     [  255  215    0]; ...   % 17Networks_LH_SalVentAttnB_Ins_1
      105, 'SalVentAttnB_Ins_2 L',     [  255  215    0]; ...   % 17Networks_LH_SalVentAttnB_Ins_2
      106, 'SalVentAttnB_Ins_3 L',     [  255  215    0]; ...   % 17Networks_LH_SalVentAttnB_Ins_3
      107, 'SalVentAttnB_OFC_1 L',     [  255  215    0]; ...   % 17Networks_LH_SalVentAttnB_OFC_1
      108, 'SalVentAttnB_PFCmp_1 L',   [  255  215    0]; ...   % 17Networks_LH_SalVentAttnB_PFCmp_1
      109, 'LimbicB_OFC_1 L',          [    0  204    0]; ...   % 17Networks_LH_LimbicB_OFC_1
      110, 'LimbicB_OFC_2 L',          [    0  204    0]; ...   % 17Networks_LH_LimbicB_OFC_2
      111, 'LimbicB_OFC_3 L',          [    0  204    0]; ...   % 17Networks_LH_LimbicB_OFC_3
      112, 'LimbicB_OFC_4 L',          [    0  204    0]; ...   % 17Networks_LH_LimbicB_OFC_4
      113, 'LimbicB_OFC_5 L',          [    0  204    0]; ...   % 17Networks_LH_LimbicB_OFC_5
      114, 'LimbicA_TempPole_1 L',     [  255    0    0]; ...   % 17Networks_LH_LimbicA_TempPole_1
      115, 'LimbicA_TempPole_2 L',     [  255    0    0]; ...   % 17Networks_LH_LimbicA_TempPole_2
      116, 'LimbicA_TempPole_3 L',     [  255    0    0]; ...   % 17Networks_LH_LimbicA_TempPole_3
      117, 'LimbicA_TempPole_4 L',     [  255    0    0]; ...   % 17Networks_LH_LimbicA_TempPole_4
      118, 'LimbicA_TempPole_5 L',     [  255    0    0]; ...   % 17Networks_LH_LimbicA_TempPole_5
      119, 'LimbicA_TempPole_6 L',     [  255    0    0]; ...   % 17Networks_LH_LimbicA_TempPole_6
      120, 'LimbicA_TempPole_7 L',     [  255    0    0]; ...   % 17Networks_LH_LimbicA_TempPole_7
      121, 'ContA_Temp_1 L',           [  102  102  255]; ...   % 17Networks_LH_ContA_Temp_1
      122, 'ContA_IPS_1 L',            [  102  102  255]; ...   % 17Networks_LH_ContA_IPS_1
      123, 'ContA_IPS_2 L',            [  102  102  255]; ...   % 17Networks_LH_ContA_IPS_2
      124, 'ContA_IPS_3 L',            [  102  102  255]; ...   % 17Networks_LH_ContA_IPS_3
      125, 'ContA_IPS_4 L',            [  102  102  255]; ...   % 17Networks_LH_ContA_IPS_4
      126, 'ContA_IPS_5 L',            [  102  102  255]; ...   % 17Networks_LH_ContA_IPS_5
      127, 'ContA_PFCd_1 L',           [  102  102  255]; ...   % 17Networks_LH_ContA_PFCd_1
      128, 'ContA_PFClv_1 L',          [  102  102  255]; ...   % 17Networks_LH_ContA_PFClv_1
      129, 'ContA_PFClv_2 L',          [  102  102  255]; ...   % 17Networks_LH_ContA_PFClv_2
      130, 'ContA_PFCl_1 L',           [  102  102  255]; ...   % 17Networks_LH_ContA_PFCl_1
      131, 'ContA_PFCl_2 L',           [  102  102  255]; ...   % 17Networks_LH_ContA_PFCl_2
      132, 'ContA_PFCl_3 L',           [  102  102  255]; ...   % 17Networks_LH_ContA_PFCl_3
      133, 'ContA_Cingm_1 L',          [  102  102  255]; ...   % 17Networks_LH_ContA_Cingm_1
      134, 'ContB_Temp_1 L',           [  255  177  100]; ...   % 17Networks_LH_ContB_Temp_1
      135, 'ContB_Temp_2 L',           [  255  177  100]; ...   % 17Networks_LH_ContB_Temp_2
      136, 'ContB_IPL_1 L',            [  255  177  100]; ...   % 17Networks_LH_ContB_IPL_1
      137, 'ContB_IPL_2 L',            [  255  177  100]; ...   % 17Networks_LH_ContB_IPL_2
      138, 'ContB_IPL_3 L',            [  255  177  100]; ...   % 17Networks_LH_ContB_IPL_3
      139, 'ContB_PFCd_1 L',           [  255  177  100]; ...   % 17Networks_LH_ContB_PFCd_1
      140, 'ContB_PFClv_1 L',          [  255  177  100]; ...   % 17Networks_LH_ContB_PFClv_1
      141, 'ContB_PFClv_2 L',          [  255  177  100]; ...   % 17Networks_LH_ContB_PFClv_2
      142, 'ContB_PFClv_3 L',          [  255  177  100]; ...   % 17Networks_LH_ContB_PFClv_3
      143, 'ContB_PFCmp_1 L',          [  255  177  100]; ...   % 17Networks_LH_ContB_PFCmp_1
      144, 'ContC_pCun_1 L',           [    0  255  255]; ...   % 17Networks_LH_ContC_pCun_1
      145, 'ContC_pCun_2 L',           [    0  255  255]; ...   % 17Networks_LH_ContC_pCun_2
      146, 'ContC_pCun_3 L',           [    0  255  255]; ...   % 17Networks_LH_ContC_pCun_3
      147, 'ContC_Cingp_1 L',          [    0  255  255]; ...   % 17Networks_LH_ContC_Cingp_1
      148, 'ContC_Cingp_2 L',          [    0  255  255]; ...   % 17Networks_LH_ContC_Cingp_2
      149, 'DefaultA_IPL_1 L',         [  255    0  255]; ...   % 17Networks_LH_DefaultA_IPL_1
      150, 'DefaultA_IPL_2 L',         [  255    0  255]; ...   % 17Networks_LH_DefaultA_IPL_2
      151, 'DefaultA_PFCd_1 L',        [  255    0  255]; ...   % 17Networks_LH_DefaultA_PFCd_1
      152, 'DefaultA_PFCd_2 L',        [  255    0  255]; ...   % 17Networks_LH_DefaultA_PFCd_2
      153, 'DefaultA_PFCd_3 L',        [  255    0  255]; ...   % 17Networks_LH_DefaultA_PFCd_3
      154, 'DefaultA_pCunPCC_1 L',     [  255    0  255]; ...   % 17Networks_LH_DefaultA_pCunPCC_1
      155, 'DefaultA_pCunPCC_2 L',     [  255    0  255]; ...   % 17Networks_LH_DefaultA_pCunPCC_2
      156, 'DefaultA_pCunPCC_3 L',     [  255    0  255]; ...   % 17Networks_LH_DefaultA_pCunPCC_3
      157, 'DefaultA_pCunPCC_4 L',     [  255    0  255]; ...   % 17Networks_LH_DefaultA_pCunPCC_4
      158, 'DefaultA_pCunPCC_5 L',     [  255    0  255]; ...   % 17Networks_LH_DefaultA_pCunPCC_5
      159, 'DefaultA_pCunPCC_6 L',     [  255    0  255]; ...   % 17Networks_LH_DefaultA_pCunPCC_6
      160, 'DefaultA_pCunPCC_7 L',     [  255    0  255]; ...   % 17Networks_LH_DefaultA_pCunPCC_7
      161, 'DefaultA_PFCm_1 L',        [  255    0  255]; ...   % 17Networks_LH_DefaultA_PFCm_1
      162, 'DefaultA_PFCm_2 L',        [  255    0  255]; ...   % 17Networks_LH_DefaultA_PFCm_2
      163, 'DefaultA_PFCm_3 L',        [  255    0  255]; ...   % 17Networks_LH_DefaultA_PFCm_3
      164, 'DefaultA_PFCm_4 L',        [  255    0  255]; ...   % 17Networks_LH_DefaultA_PFCm_4
      165, 'DefaultA_PFCm_5 L',        [  255    0  255]; ...   % 17Networks_LH_DefaultA_PFCm_5
      166, 'DefaultA_PFCm_6 L',        [  255    0  255]; ...   % 17Networks_LH_DefaultA_PFCm_6
      167, 'DefaultB_Temp_1 L',        [  102    0    0]; ...   % 17Networks_LH_DefaultB_Temp_1
      168, 'DefaultB_Temp_2 L',        [  102    0    0]; ...   % 17Networks_LH_DefaultB_Temp_2
      169, 'DefaultB_Temp_3 L',        [  102    0    0]; ...   % 17Networks_LH_DefaultB_Temp_3
      170, 'DefaultB_Temp_4 L',        [  102    0    0]; ...   % 17Networks_LH_DefaultB_Temp_4
      171, 'DefaultB_Temp_5 L',        [  102    0    0]; ...   % 17Networks_LH_DefaultB_Temp_5
      172, 'DefaultB_Temp_6 L',        [  102    0    0]; ...   % 17Networks_LH_DefaultB_Temp_6
      173, 'DefaultB_IPL_1 L',         [  102    0    0]; ...   % 17Networks_LH_DefaultB_IPL_1
      174, 'DefaultB_IPL_2 L',         [  102    0    0]; ...   % 17Networks_LH_DefaultB_IPL_2
      175, 'DefaultB_PFCd_1 L',        [  102    0    0]; ...   % 17Networks_LH_DefaultB_PFCd_1
      176, 'DefaultB_PFCd_2 L',        [  102    0    0]; ...   % 17Networks_LH_DefaultB_PFCd_2
      177, 'DefaultB_PFCd_3 L',        [  102    0    0]; ...   % 17Networks_LH_DefaultB_PFCd_3
      178, 'DefaultB_PFCd_4 L',        [  102    0    0]; ...   % 17Networks_LH_DefaultB_PFCd_4
      179, 'DefaultB_PFCd_5 L',        [  102    0    0]; ...   % 17Networks_LH_DefaultB_PFCd_5
      180, 'DefaultB_PFCd_6 L',        [  102    0    0]; ...   % 17Networks_LH_DefaultB_PFCd_6
      181, 'DefaultB_PFCl_1 L',        [  102    0    0]; ...   % 17Networks_LH_DefaultB_PFCl_1
      182, 'DefaultB_PFCl_2 L',        [  102    0    0]; ...   % 17Networks_LH_DefaultB_PFCl_2
      183, 'DefaultB_PFCv_1 L',        [  102    0    0]; ...   % 17Networks_LH_DefaultB_PFCv_1
      184, 'DefaultB_PFCv_2 L',        [  102    0    0]; ...   % 17Networks_LH_DefaultB_PFCv_2
      185, 'DefaultB_PFCv_3 L',        [  102    0    0]; ...   % 17Networks_LH_DefaultB_PFCv_3
      186, 'DefaultB_PFCv_4 L',        [  102    0    0]; ...   % 17Networks_LH_DefaultB_PFCv_4
      187, 'DefaultB_PFCv_5 L',        [  102    0    0]; ...   % 17Networks_LH_DefaultB_PFCv_5
      188, 'DefaultC_IPL_1 L',         [    0  102    0]; ...   % 17Networks_LH_DefaultC_IPL_1
      189, 'DefaultC_Rsp_1 L',         [    0  102    0]; ...   % 17Networks_LH_DefaultC_Rsp_1
      190, 'DefaultC_Rsp_2 L',         [    0  102    0]; ...   % 17Networks_LH_DefaultC_Rsp_2
      191, 'DefaultC_Rsp_3 L',         [    0  102    0]; ...   % 17Networks_LH_DefaultC_Rsp_3
      192, 'DefaultC_PHC_1 L',         [    0  102    0]; ...   % 17Networks_LH_DefaultC_PHC_1
      193, 'DefaultC_PHC_2 L',         [    0  102    0]; ...   % 17Networks_LH_DefaultC_PHC_2
      194, 'DefaultC_PHC_3 L',         [    0  102    0]; ...   % 17Networks_LH_DefaultC_PHC_3
      195, 'TempPar_1 L',              [  255  215    0]; ...   % 17Networks_LH_TempPar_1
      196, 'TempPar_2 L',              [  255  215    0]; ...   % 17Networks_LH_TempPar_2
      197, 'TempPar_3 L',              [  255  215    0]; ...   % 17Networks_LH_TempPar_3
      198, 'TempPar_4 L',              [  255  215    0]; ...   % 17Networks_LH_TempPar_4
      199, 'TempPar_5 L',              [  255  215    0]; ...   % 17Networks_LH_TempPar_5
      200, 'TempPar_6 L',              [  255  215    0]; ...   % 17Networks_LH_TempPar_6
      201, 'VisCent_ExStr_1 R',        [  255    0    0]; ...   % 17Networks_RH_VisCent_ExStr_1
      202, 'VisCent_ExStr_2 R',        [  255    0    0]; ...   % 17Networks_RH_VisCent_ExStr_2
      203, 'VisCent_ExStr_3 R',        [  255    0    0]; ...   % 17Networks_RH_VisCent_ExStr_3
      204, 'VisCent_ExStr_4 R',        [  255    0    0]; ...   % 17Networks_RH_VisCent_ExStr_4
      205, 'VisCent_ExStr_5 R',        [  255    0    0]; ...   % 17Networks_RH_VisCent_ExStr_5
      206, 'VisCent_ExStr_6 R',        [  255    0    0]; ...   % 17Networks_RH_VisCent_ExStr_6
      207, 'VisCent_Striate_1 R',      [  255    0    0]; ...   % 17Networks_RH_VisCent_Striate_1
      208, 'VisCent_ExStr_7 R',        [  255    0    0]; ...   % 17Networks_RH_VisCent_ExStr_7
      209, 'VisCent_ExStr_8 R',        [  255    0    0]; ...   % 17Networks_RH_VisCent_ExStr_8
      210, 'VisCent_ExStr_9 R',        [  255    0    0]; ...   % 17Networks_RH_VisCent_ExStr_9
      211, 'VisCent_ExStr_10 R',       [  255    0    0]; ...   % 17Networks_RH_VisCent_ExStr_10
      212, 'VisCent_ExStr_11 R',       [  255    0    0]; ...   % 17Networks_RH_VisCent_ExStr_11
      213, 'VisPeri_ExStrInf_1 R',     [  102  102  255]; ...   % 17Networks_RH_VisPeri_ExStrInf_1
      214, 'VisPeri_ExStrInf_2 R',     [  102  102  255]; ...   % 17Networks_RH_VisPeri_ExStrInf_2
      215, 'VisPeri_ExStrInf_3 R',     [  102  102  255]; ...   % 17Networks_RH_VisPeri_ExStrInf_3
      216, 'VisPeri_ExStrInf_4 R',     [  102  102  255]; ...   % 17Networks_RH_VisPeri_ExStrInf_4
      217, 'VisPeri_ExStrInf_5 R',     [  102  102  255]; ...   % 17Networks_RH_VisPeri_ExStrInf_5
      218, 'VisPeri_StriCal_1 R',      [  102  102  255]; ...   % 17Networks_RH_VisPeri_StriCal_1
      219, 'VisPeri_StriCal_2 R',      [  102  102  255]; ...   % 17Networks_RH_VisPeri_StriCal_2
      220, 'VisPeri_ExStrSup_1 R',     [  102  102  255]; ...   % 17Networks_RH_VisPeri_ExStrSup_1
      221, 'VisPeri_ExStrSup_2 R',     [  102  102  255]; ...   % 17Networks_RH_VisPeri_ExStrSup_2
      222, 'VisPeri_ExStrSup_3 R',     [  102  102  255]; ...   % 17Networks_RH_VisPeri_ExStrSup_3
      223, 'VisPeri_ExStrSup_4 R',     [  102  102  255]; ...   % 17Networks_RH_VisPeri_ExStrSup_4
      224, 'SomMotA_1 R',              [  255  177  100]; ...   % 17Networks_RH_SomMotA_1
      225, 'SomMotA_2 R',              [  255  177  100]; ...   % 17Networks_RH_SomMotA_2
      226, 'SomMotA_3 R',              [  255  177  100]; ...   % 17Networks_RH_SomMotA_3
      227, 'SomMotA_4 R',              [  255  177  100]; ...   % 17Networks_RH_SomMotA_4
      228, 'SomMotA_5 R',              [  255  177  100]; ...   % 17Networks_RH_SomMotA_5
      229, 'SomMotA_6 R',              [  255  177  100]; ...   % 17Networks_RH_SomMotA_6
      230, 'SomMotA_7 R',              [  255  177  100]; ...   % 17Networks_RH_SomMotA_7
      231, 'SomMotA_8 R',              [  255  177  100]; ...   % 17Networks_RH_SomMotA_8
      232, 'SomMotA_9 R',              [  255  177  100]; ...   % 17Networks_RH_SomMotA_9
      233, 'SomMotA_10 R',             [  255  177  100]; ...   % 17Networks_RH_SomMotA_10
      234, 'SomMotA_11 R',             [  255  177  100]; ...   % 17Networks_RH_SomMotA_11
      235, 'SomMotA_12 R',             [  255  177  100]; ...   % 17Networks_RH_SomMotA_12
      236, 'SomMotA_13 R',             [  255  177  100]; ...   % 17Networks_RH_SomMotA_13
      237, 'SomMotA_14 R',             [  255  177  100]; ...   % 17Networks_RH_SomMotA_14
      238, 'SomMotA_15 R',             [  255  177  100]; ...   % 17Networks_RH_SomMotA_15
      239, 'SomMotA_16 R',             [  255  177  100]; ...   % 17Networks_RH_SomMotA_16
      240, 'SomMotA_17 R',             [  255  177  100]; ...   % 17Networks_RH_SomMotA_17
      241, 'SomMotA_18 R',             [  255  177  100]; ...   % 17Networks_RH_SomMotA_18
      242, 'SomMotA_19 R',             [  255  177  100]; ...   % 17Networks_RH_SomMotA_19
      243, 'SomMotA_20 R',             [  255  177  100]; ...   % 17Networks_RH_SomMotA_20
      244, 'SomMotB_Aud_1 R',          [    0  255  255]; ...   % 17Networks_RH_SomMotB_Aud_1
      245, 'SomMotB_Aud_2 R',          [    0  255  255]; ...   % 17Networks_RH_SomMotB_Aud_2
      246, 'SomMotB_Ins_1 R',          [    0  255  255]; ...   % 17Networks_RH_SomMotB_Ins_1
      247, 'SomMotB_S2_1 R',           [    0  255  255]; ...   % 17Networks_RH_SomMotB_S2_1
      248, 'SomMotB_S2_2 R',           [    0  255  255]; ...   % 17Networks_RH_SomMotB_S2_2
      249, 'SomMotB_Aud_3 R',          [    0  255  255]; ...   % 17Networks_RH_SomMotB_Aud_3
      250, 'SomMotB_S2_3 R',           [    0  255  255]; ...   % 17Networks_RH_SomMotB_S2_3
      251, 'SomMotB_S2_4 R',           [    0  255  255]; ...   % 17Networks_RH_SomMotB_S2_4
      252, 'SomMotB_S2_5 R',           [    0  255  255]; ...   % 17Networks_RH_SomMotB_S2_5
      253, 'SomMotB_S2_6 R',           [    0  255  255]; ...   % 17Networks_RH_SomMotB_S2_6
      254, 'SomMotB_S2_7 R',           [    0  255  255]; ...   % 17Networks_RH_SomMotB_S2_7
      255, 'SomMotB_S2_8 R',           [    0  255  255]; ...   % 17Networks_RH_SomMotB_S2_8
      256, 'SomMotB_Cent_1 R',         [    0  255  255]; ...   % 17Networks_RH_SomMotB_Cent_1
      257, 'SomMotB_Cent_2 R',         [    0  255  255]; ...   % 17Networks_RH_SomMotB_Cent_2
      258, 'SomMotB_Cent_3 R',         [    0  255  255]; ...   % 17Networks_RH_SomMotB_Cent_3
      259, 'DorsAttnA_TempOcc_1 R',    [  255    0  255]; ...   % 17Networks_RH_DorsAttnA_TempOcc_1
      260, 'DorsAttnA_TempOcc_2 R',    [  255    0  255]; ...   % 17Networks_RH_DorsAttnA_TempOcc_2
      261, 'DorsAttnA_TempOcc_3 R',    [  255    0  255]; ...   % 17Networks_RH_DorsAttnA_TempOcc_3
      262, 'DorsAttnA_ParOcc_1 R',     [  255    0  255]; ...   % 17Networks_RH_DorsAttnA_ParOcc_1
      263, 'DorsAttnA_ParOcc_2 R',     [  255    0  255]; ...   % 17Networks_RH_DorsAttnA_ParOcc_2
      264, 'DorsAttnA_ParOcc_3 R',     [  255    0  255]; ...   % 17Networks_RH_DorsAttnA_ParOcc_3
      265, 'DorsAttnA_SPL_1 R',        [  255    0  255]; ...   % 17Networks_RH_DorsAttnA_SPL_1
      266, 'DorsAttnA_SPL_2 R',        [  255    0  255]; ...   % 17Networks_RH_DorsAttnA_SPL_2
      267, 'DorsAttnA_SPL_3 R',        [  255    0  255]; ...   % 17Networks_RH_DorsAttnA_SPL_3
      268, 'DorsAttnA_SPL_4 R',        [  255    0  255]; ...   % 17Networks_RH_DorsAttnA_SPL_4
      269, 'DorsAttnA_SPL_5 R',        [  255    0  255]; ...   % 17Networks_RH_DorsAttnA_SPL_5
      270, 'DorsAttnA_SPL_6 R',        [  255    0  255]; ...   % 17Networks_RH_DorsAttnA_SPL_6
      271, 'DorsAttnA_SPL_7 R',        [  255    0  255]; ...   % 17Networks_RH_DorsAttnA_SPL_7
      272, 'DorsAttnA_SPL_8 R',        [  255    0  255]; ...   % 17Networks_RH_DorsAttnA_SPL_8
      273, 'DorsAttnB_TempOcc_1 R',    [  102    0    0]; ...   % 17Networks_RH_DorsAttnB_TempOcc_1
      274, 'DorsAttnB_PostC_1 R',      [  102    0    0]; ...   % 17Networks_RH_DorsAttnB_PostC_1
      275, 'DorsAttnB_PostC_2 R',      [  102    0    0]; ...   % 17Networks_RH_DorsAttnB_PostC_2
      276, 'DorsAttnB_PostC_3 R',      [  102    0    0]; ...   % 17Networks_RH_DorsAttnB_PostC_3
      277, 'DorsAttnB_PostC_4 R',      [  102    0    0]; ...   % 17Networks_RH_DorsAttnB_PostC_4
      278, 'DorsAttnB_PostC_5 R',      [  102    0    0]; ...   % 17Networks_RH_DorsAttnB_PostC_5
      279, 'DorsAttnB_PostC_6 R',      [  102    0    0]; ...   % 17Networks_RH_DorsAttnB_PostC_6
      280, 'DorsAttnB_PostC_7 R',      [  102    0    0]; ...   % 17Networks_RH_DorsAttnB_PostC_7
      281, 'DorsAttnB_PostC_8 R',      [  102    0    0]; ...   % 17Networks_RH_DorsAttnB_PostC_8
      282, 'DorsAttnB_FEF_1 R',        [  102    0    0]; ...   % 17Networks_RH_DorsAttnB_FEF_1
      283, 'DorsAttnB_FEF_2 R',        [  102    0    0]; ...   % 17Networks_RH_DorsAttnB_FEF_2
      284, 'DorsAttnB_FEF_3 R',        [  102    0    0]; ...   % 17Networks_RH_DorsAttnB_FEF_3
      285, 'SalVentAttnA_ParOper_1 R', [    0  102    0]; ...   % 17Networks_RH_SalVentAttnA_ParOper_1
      286, 'SalVentAttnA_ParOper_2 R', [    0  102    0]; ...   % 17Networks_RH_SalVentAttnA_ParOper_2
      287, 'SalVentAttnA_ParOper_3 R', [    0  102    0]; ...   % 17Networks_RH_SalVentAttnA_ParOper_3
      288, 'SalVentAttnA_PrC_1 R',     [    0  102    0]; ...   % 17Networks_RH_SalVentAttnA_PrC_1
      289, 'SalVentAttnA_Ins_1 R',     [    0  102    0]; ...   % 17Networks_RH_SalVentAttnA_Ins_1
      290, 'SalVentAttnA_Ins_2 R',     [    0  102    0]; ...   % 17Networks_RH_SalVentAttnA_Ins_2
      291, 'SalVentAttnA_Ins_3 R',     [    0  102    0]; ...   % 17Networks_RH_SalVentAttnA_Ins_3
      292, 'SalVentAttnA_Ins_4 R',     [    0  102    0]; ...   % 17Networks_RH_SalVentAttnA_Ins_4
      293, 'SalVentAttnA_FrOper_1 R',  [    0  102    0]; ...   % 17Networks_RH_SalVentAttnA_FrOper_1
      294, 'SalVentAttnA_FrOper_2 R',  [    0  102    0]; ...   % 17Networks_RH_SalVentAttnA_FrOper_2
      295, 'SalVentAttnA_FrOper_3 R',  [    0  102    0]; ...   % 17Networks_RH_SalVentAttnA_FrOper_3
      296, 'SalVentAttnA_FrMed_1 R',   [    0  102    0]; ...   % 17Networks_RH_SalVentAttnA_FrMed_1
      297, 'SalVentAttnA_ParMed_1 R',  [    0  102    0]; ...   % 17Networks_RH_SalVentAttnA_ParMed_1
      298, 'SalVentAttnA_ParMed_2 R',  [    0  102    0]; ...   % 17Networks_RH_SalVentAttnA_ParMed_2
      299, 'SalVentAttnA_FrMed_2 R',   [    0  102    0]; ...   % 17Networks_RH_SalVentAttnA_FrMed_2
      300, 'SalVentAttnA_ParMed_3 R',  [    0  102    0]; ...   % 17Networks_RH_SalVentAttnA_ParMed_3
      301, 'SalVentAttnA_ParMed_4 R',  [    0  102    0]; ...   % 17Networks_RH_SalVentAttnA_ParMed_4
      302, 'SalVentAttnA_FrMed_3 R',   [    0  102    0]; ...   % 17Networks_RH_SalVentAttnA_FrMed_3
      303, 'SalVentAttnA_FrMed_4 R',   [    0  102    0]; ...   % 17Networks_RH_SalVentAttnA_FrMed_4
      304, 'SalVentAttnB_IPL_1 R',     [  255  215    0]; ...   % 17Networks_RH_SalVentAttnB_IPL_1
      305, 'SalVentAttnB_PFClv_1 R',   [  255  215    0]; ...   % 17Networks_RH_SalVentAttnB_PFClv_1
      306, 'SalVentAttnB_PFCl_1 R',    [  255  215    0]; ...   % 17Networks_RH_SalVentAttnB_PFCl_1
      307, 'SalVentAttnB_PFCl_2 R',    [  255  215    0]; ...   % 17Networks_RH_SalVentAttnB_PFCl_2
      308, 'SalVentAttnB_PFCl_3 R',    [  255  215    0]; ...   % 17Networks_RH_SalVentAttnB_PFCl_3
      309, 'SalVentAttnB_Ins_1 R',     [  255  215    0]; ...   % 17Networks_RH_SalVentAttnB_Ins_1
      310, 'SalVentAttnB_Ins_2 R',     [  255  215    0]; ...   % 17Networks_RH_SalVentAttnB_Ins_2
      311, 'SalVentAttnB_PFCmp_1 R',   [  255  215    0]; ...   % 17Networks_RH_SalVentAttnB_PFCmp_1
      312, 'SalVentAttnB_PFCmp_2 R',   [  255  215    0]; ...   % 17Networks_RH_SalVentAttnB_PFCmp_2
      313, 'LimbicB_OFC_1 R',          [    0  204    0]; ...   % 17Networks_RH_LimbicB_OFC_1
      314, 'LimbicB_OFC_2 R',          [    0  204    0]; ...   % 17Networks_RH_LimbicB_OFC_2
      315, 'LimbicB_OFC_3 R',          [    0  204    0]; ...   % 17Networks_RH_LimbicB_OFC_3
      316, 'LimbicB_OFC_4 R',          [    0  204    0]; ...   % 17Networks_RH_LimbicB_OFC_4
      317, 'LimbicB_OFC_5 R',          [    0  204    0]; ...   % 17Networks_RH_LimbicB_OFC_5
      318, 'LimbicB_OFC_6 R',          [    0  204    0]; ...   % 17Networks_RH_LimbicB_OFC_6
      319, 'LimbicA_TempPole_1 R',     [  255    0    0]; ...   % 17Networks_RH_LimbicA_TempPole_1
      320, 'LimbicA_TempPole_2 R',     [  255    0    0]; ...   % 17Networks_RH_LimbicA_TempPole_2
      321, 'LimbicA_TempPole_3 R',     [  255    0    0]; ...   % 17Networks_RH_LimbicA_TempPole_3
      322, 'LimbicA_TempPole_4 R',     [  255    0    0]; ...   % 17Networks_RH_LimbicA_TempPole_4
      323, 'LimbicA_TempPole_5 R',     [  255    0    0]; ...   % 17Networks_RH_LimbicA_TempPole_5
      324, 'LimbicA_TempPole_6 R',     [  255    0    0]; ...   % 17Networks_RH_LimbicA_TempPole_6
      325, 'ContA_IPS_1 R',            [  102  102  255]; ...   % 17Networks_RH_ContA_IPS_1
      326, 'ContA_IPS_2 R',            [  102  102  255]; ...   % 17Networks_RH_ContA_IPS_2
      327, 'ContA_IPS_3 R',            [  102  102  255]; ...   % 17Networks_RH_ContA_IPS_3
      328, 'ContA_IPS_4 R',            [  102  102  255]; ...   % 17Networks_RH_ContA_IPS_4
      329, 'ContA_PFCd_1 R',           [  102  102  255]; ...   % 17Networks_RH_ContA_PFCd_1
      330, 'ContA_PFCl_1 R',           [  102  102  255]; ...   % 17Networks_RH_ContA_PFCl_1
      331, 'ContA_PFCl_2 R',           [  102  102  255]; ...   % 17Networks_RH_ContA_PFCl_2
      332, 'ContA_PFCl_3 R',           [  102  102  255]; ...   % 17Networks_RH_ContA_PFCl_3
      333, 'ContA_PFCl_4 R',           [  102  102  255]; ...   % 17Networks_RH_ContA_PFCl_4
      334, 'ContA_PFCl_5 R',           [  102  102  255]; ...   % 17Networks_RH_ContA_PFCl_5
      335, 'ContA_Cingm_1 R',          [  102  102  255]; ...   % 17Networks_RH_ContA_Cingm_1
      336, 'ContB_Temp_1 R',           [  255  177  100]; ...   % 17Networks_RH_ContB_Temp_1
      337, 'ContB_Temp_2 R',           [  255  177  100]; ...   % 17Networks_RH_ContB_Temp_2
      338, 'ContB_IPL_1 R',            [  255  177  100]; ...   % 17Networks_RH_ContB_IPL_1
      339, 'ContB_IPL_2 R',            [  255  177  100]; ...   % 17Networks_RH_ContB_IPL_2
      340, 'ContB_IPL_3 R',            [  255  177  100]; ...   % 17Networks_RH_ContB_IPL_3
      341, 'ContB_IPL_4 R',            [  255  177  100]; ...   % 17Networks_RH_ContB_IPL_4
      342, 'ContB_PFCld_1 R',          [  255  177  100]; ...   % 17Networks_RH_ContB_PFCld_1
      343, 'ContB_PFCld_2 R',          [  255  177  100]; ...   % 17Networks_RH_ContB_PFCld_2
      344, 'ContB_PFCld_3 R',          [  255  177  100]; ...   % 17Networks_RH_ContB_PFCld_3
      345, 'ContB_PFCld_4 R',          [  255  177  100]; ...   % 17Networks_RH_ContB_PFCld_4
      346, 'ContB_PFClv_1 R',          [  255  177  100]; ...   % 17Networks_RH_ContB_PFClv_1
      347, 'ContB_PFClv_2 R',          [  255  177  100]; ...   % 17Networks_RH_ContB_PFClv_2
      348, 'ContB_PFClv_3 R',          [  255  177  100]; ...   % 17Networks_RH_ContB_PFClv_3
      349, 'ContB_PFClv_4 R',          [  255  177  100]; ...   % 17Networks_RH_ContB_PFClv_4
      350, 'ContB_PFCmp_1 R',          [  255  177  100]; ...   % 17Networks_RH_ContB_PFCmp_1
      351, 'ContC_pCun_1 R',           [    0  255  255]; ...   % 17Networks_RH_ContC_pCun_1
      352, 'ContC_pCun_2 R',           [    0  255  255]; ...   % 17Networks_RH_ContC_pCun_2
      353, 'ContC_pCun_3 R',           [    0  255  255]; ...   % 17Networks_RH_ContC_pCun_3
      354, 'ContC_pCun_4 R',           [    0  255  255]; ...   % 17Networks_RH_ContC_pCun_4
      355, 'ContC_pCun_5 R',           [    0  255  255]; ...   % 17Networks_RH_ContC_pCun_5
      356, 'ContC_Cingp_1 R',          [    0  255  255]; ...   % 17Networks_RH_ContC_Cingp_1
      357, 'ContC_Cingp_2 R',          [    0  255  255]; ...   % 17Networks_RH_ContC_Cingp_2
      358, 'DefaultA_Temp_1 R',        [  255    0  255]; ...   % 17Networks_RH_DefaultA_Temp_1
      359, 'DefaultA_IPL_1 R',         [  255    0  255]; ...   % 17Networks_RH_DefaultA_IPL_1
      360, 'DefaultA_IPL_2 R',         [  255    0  255]; ...   % 17Networks_RH_DefaultA_IPL_2
      361, 'DefaultA_PFCd_1 R',        [  255    0  255]; ...   % 17Networks_RH_DefaultA_PFCd_1
      362, 'DefaultA_PFCd_2 R',        [  255    0  255]; ...   % 17Networks_RH_DefaultA_PFCd_2
      363, 'DefaultA_pCunPCC_1 R',     [  255    0  255]; ...   % 17Networks_RH_DefaultA_pCunPCC_1
      364, 'DefaultA_pCunPCC_2 R',     [  255    0  255]; ...   % 17Networks_RH_DefaultA_pCunPCC_2
      365, 'DefaultA_pCunPCC_3 R',     [  255    0  255]; ...   % 17Networks_RH_DefaultA_pCunPCC_3
      366, 'DefaultA_pCunPCC_4 R',     [  255    0  255]; ...   % 17Networks_RH_DefaultA_pCunPCC_4
      367, 'DefaultA_pCunPCC_5 R',     [  255    0  255]; ...   % 17Networks_RH_DefaultA_pCunPCC_5
      368, 'DefaultA_PFCm_1 R',        [  255    0  255]; ...   % 17Networks_RH_DefaultA_PFCm_1
      369, 'DefaultA_PFCm_2 R',        [  255    0  255]; ...   % 17Networks_RH_DefaultA_PFCm_2
      370, 'DefaultA_PFCm_3 R',        [  255    0  255]; ...   % 17Networks_RH_DefaultA_PFCm_3
      371, 'DefaultA_PFCm_4 R',        [  255    0  255]; ...   % 17Networks_RH_DefaultA_PFCm_4
      372, 'DefaultA_PFCm_5 R',        [  255    0  255]; ...   % 17Networks_RH_DefaultA_PFCm_5
      373, 'DefaultA_PFCm_6 R',        [  255    0  255]; ...   % 17Networks_RH_DefaultA_PFCm_6
      374, 'DefaultB_Temp_1 R',        [  102    0    0]; ...   % 17Networks_RH_DefaultB_Temp_1
      375, 'DefaultB_Temp_2 R',        [  102    0    0]; ...   % 17Networks_RH_DefaultB_Temp_2
      376, 'DefaultB_AntTemp_1 R',     [  102    0    0]; ...   % 17Networks_RH_DefaultB_AntTemp_1
      377, 'DefaultB_PFCd_1 R',        [  102    0    0]; ...   % 17Networks_RH_DefaultB_PFCd_1
      378, 'DefaultB_PFCd_2 R',        [  102    0    0]; ...   % 17Networks_RH_DefaultB_PFCd_2
      379, 'DefaultB_PFCd_3 R',        [  102    0    0]; ...   % 17Networks_RH_DefaultB_PFCd_3
      380, 'DefaultB_PFCd_4 R',        [  102    0    0]; ...   % 17Networks_RH_DefaultB_PFCd_4
      381, 'DefaultB_PFCd_5 R',        [  102    0    0]; ...   % 17Networks_RH_DefaultB_PFCd_5
      382, 'DefaultB_PFCv_1 R',        [  102    0    0]; ...   % 17Networks_RH_DefaultB_PFCv_1
      383, 'DefaultB_PFCv_2 R',        [  102    0    0]; ...   % 17Networks_RH_DefaultB_PFCv_2
      384, 'DefaultB_PFCv_3 R',        [  102    0    0]; ...   % 17Networks_RH_DefaultB_PFCv_3
      385, 'DefaultC_IPL_1 R',         [    0  102    0]; ...   % 17Networks_RH_DefaultC_IPL_1
      386, 'DefaultC_IPL_2 R',         [    0  102    0]; ...   % 17Networks_RH_DefaultC_IPL_2
      387, 'DefaultC_Rsp_1 R',         [    0  102    0]; ...   % 17Networks_RH_DefaultC_Rsp_1
      388, 'DefaultC_Rsp_2 R',         [    0  102    0]; ...   % 17Networks_RH_DefaultC_Rsp_2
      389, 'DefaultC_PHC_1 R',         [    0  102    0]; ...   % 17Networks_RH_DefaultC_PHC_1
      390, 'DefaultC_PHC_2 R',         [    0  102    0]; ...   % 17Networks_RH_DefaultC_PHC_2
      391, 'TempPar_1 R',              [  255  215    0]; ...   % 17Networks_RH_TempPar_1
      392, 'TempPar_2 R',              [  255  215    0]; ...   % 17Networks_RH_TempPar_2
      393, 'TempPar_3 R',              [  255  215    0]; ...   % 17Networks_RH_TempPar_3
      394, 'TempPar_4 R',              [  255  215    0]; ...   % 17Networks_RH_TempPar_4
      395, 'TempPar_5 R',              [  255  215    0]; ...   % 17Networks_RH_TempPar_5
      396, 'TempPar_6 R',              [  255  215    0]; ...   % 17Networks_RH_TempPar_6
      397, 'TempPar_7 R',              [  255  215    0]; ...   % 17Networks_RH_TempPar_7
      398, 'TempPar_8 R',              [  255  215    0]; ...   % 17Networks_RH_TempPar_8
      399, 'TempPar_9 R',              [  255  215    0]; ...   % 17Networks_RH_TempPar_9
      400, 'TempPar_10 R',             [  255  215    0]; ...   % 17Networks_RH_TempPar_10
};
