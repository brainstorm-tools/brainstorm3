function Labels = mri_getlabels_shaeffer200()
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
        0, 'Background',               [    0    0    0]; ...
        1, 'VisCent_ExStr_1 L',        [  255    0    0]; ...   % 17Networks_LH_VisCent_ExStr_1
        2, 'VisCent_ExStr_2 L',        [  255    0    0]; ...   % 17Networks_LH_VisCent_ExStr_2
        3, 'VisCent_Striate_1 L',      [  255    0    0]; ...   % 17Networks_LH_VisCent_Striate_1
        4, 'VisCent_ExStr_3 L',        [  255    0    0]; ...   % 17Networks_LH_VisCent_ExStr_3
        5, 'VisCent_ExStr_4 L',        [  255    0    0]; ...   % 17Networks_LH_VisCent_ExStr_4
        6, 'VisCent_ExStr_5 L',        [  255    0    0]; ...   % 17Networks_LH_VisCent_ExStr_5
        7, 'VisPeri_ExStrInf_1 L',     [  102  102  255]; ...   % 17Networks_LH_VisPeri_ExStrInf_1
        8, 'VisPeri_ExStrInf_2 L',     [  102  102  255]; ...   % 17Networks_LH_VisPeri_ExStrInf_2
        9, 'VisPeri_ExStrInf_3 L',     [  102  102  255]; ...   % 17Networks_LH_VisPeri_ExStrInf_3
       10, 'VisPeri_StriCal_1 L',      [  102  102  255]; ...   % 17Networks_LH_VisPeri_StriCal_1
       11, 'VisPeri_ExStrSup_1 L',     [  102  102  255]; ...   % 17Networks_LH_VisPeri_ExStrSup_1
       12, 'VisPeri_ExStrSup_2 L',     [  102  102  255]; ...   % 17Networks_LH_VisPeri_ExStrSup_2
       13, 'SomMotA_1 L',              [  255  177  100]; ...   % 17Networks_LH_SomMotA_1
       14, 'SomMotA_2 L',              [  255  177  100]; ...   % 17Networks_LH_SomMotA_2
       15, 'SomMotA_3 L',              [  255  177  100]; ...   % 17Networks_LH_SomMotA_3
       16, 'SomMotA_4 L',              [  255  177  100]; ...   % 17Networks_LH_SomMotA_4
       17, 'SomMotA_5 L',              [  255  177  100]; ...   % 17Networks_LH_SomMotA_5
       18, 'SomMotA_6 L',              [  255  177  100]; ...   % 17Networks_LH_SomMotA_6
       19, 'SomMotA_7 L',              [  255  177  100]; ...   % 17Networks_LH_SomMotA_7
       20, 'SomMotA_8 L',              [  255  177  100]; ...   % 17Networks_LH_SomMotA_8
       21, 'SomMotB_Aud_1 L',          [    0  255  255]; ...   % 17Networks_LH_SomMotB_Aud_1
       22, 'SomMotB_Aud_2 L',          [    0  255  255]; ...   % 17Networks_LH_SomMotB_Aud_2
       23, 'SomMotB_S2_1 L',           [    0  255  255]; ...   % 17Networks_LH_SomMotB_S2_1
       24, 'SomMotB_S2_2 L',           [    0  255  255]; ...   % 17Networks_LH_SomMotB_S2_2
       25, 'SomMotB_Aud_3 L',          [    0  255  255]; ...   % 17Networks_LH_SomMotB_Aud_3
       26, 'SomMotB_S2_3 L',           [    0  255  255]; ...   % 17Networks_LH_SomMotB_S2_3
       27, 'SomMotB_Cent_1 L',         [    0  255  255]; ...   % 17Networks_LH_SomMotB_Cent_1
       28, 'SomMotB_Cent_2 L',         [    0  255  255]; ...   % 17Networks_LH_SomMotB_Cent_2
       29, 'DorsAttnA_TempOcc_1 L',    [  255    0  255]; ...   % 17Networks_LH_DorsAttnA_TempOcc_1
       30, 'DorsAttnA_TempOcc_2 L',    [  255    0  255]; ...   % 17Networks_LH_DorsAttnA_TempOcc_2
       31, 'DorsAttnA_ParOcc_1 L',     [  255    0  255]; ...   % 17Networks_LH_DorsAttnA_ParOcc_1
       32, 'DorsAttnA_SPL_1 L',        [  255    0  255]; ...   % 17Networks_LH_DorsAttnA_SPL_1
       33, 'DorsAttnA_SPL_2 L',        [  255    0  255]; ...   % 17Networks_LH_DorsAttnA_SPL_2
       34, 'DorsAttnA_SPL_3 L',        [  255    0  255]; ...   % 17Networks_LH_DorsAttnA_SPL_3
       35, 'DorsAttnB_PostC_1 L',      [  102    0    0]; ...   % 17Networks_LH_DorsAttnB_PostC_1
       36, 'DorsAttnB_PostC_2 L',      [  102    0    0]; ...   % 17Networks_LH_DorsAttnB_PostC_2
       37, 'DorsAttnB_PostC_3 L',      [  102    0    0]; ...   % 17Networks_LH_DorsAttnB_PostC_3
       38, 'DorsAttnB_PostC_4 L',      [  102    0    0]; ...   % 17Networks_LH_DorsAttnB_PostC_4
       39, 'DorsAttnB_FEF_1 L',        [  102    0    0]; ...   % 17Networks_LH_DorsAttnB_FEF_1
       40, 'SalVentAttnA_ParOper_1 L', [    0  102    0]; ...   % 17Networks_LH_SalVentAttnA_ParOper_1
       41, 'SalVentAttnA_Ins_1 L',     [    0  102    0]; ...   % 17Networks_LH_SalVentAttnA_Ins_1
       42, 'SalVentAttnA_FrOper_1 L',  [    0  102    0]; ...   % 17Networks_LH_SalVentAttnA_FrOper_1
       43, 'SalVentAttnA_FrOper_2 L',  [    0  102    0]; ...   % 17Networks_LH_SalVentAttnA_FrOper_2
       44, 'SalVentAttnA_ParMed_1 L',  [    0  102    0]; ...   % 17Networks_LH_SalVentAttnA_ParMed_1
       45, 'SalVentAttnA_FrMed_1 L',   [    0  102    0]; ...   % 17Networks_LH_SalVentAttnA_FrMed_1
       46, 'SalVentAttnA_FrMed_2 L',   [    0  102    0]; ...   % 17Networks_LH_SalVentAttnA_FrMed_2
       47, 'SalVentAttnB_IPL_1 L',     [  255  215    0]; ...   % 17Networks_LH_SalVentAttnB_IPL_1
       48, 'SalVentAttnB_PFCl_1 L',    [  255  215    0]; ...   % 17Networks_LH_SalVentAttnB_PFCl_1
       49, 'SalVentAttnB_Ins_1 L',     [  255  215    0]; ...   % 17Networks_LH_SalVentAttnB_Ins_1
       50, 'SalVentAttnB_PFCmp_1 L',   [  255  215    0]; ...   % 17Networks_LH_SalVentAttnB_PFCmp_1
       51, 'LimbicB_OFC_1 L',          [    0  204    0]; ...   % 17Networks_LH_LimbicB_OFC_1
       52, 'LimbicB_OFC_2 L',          [    0  204    0]; ...   % 17Networks_LH_LimbicB_OFC_2
       53, 'LimbicA_TempPole_1 L',     [  255    0    0]; ...   % 17Networks_LH_LimbicA_TempPole_1
       54, 'LimbicA_TempPole_2 L',     [  255    0    0]; ...   % 17Networks_LH_LimbicA_TempPole_2
       55, 'LimbicA_TempPole_3 L',     [  255    0    0]; ...   % 17Networks_LH_LimbicA_TempPole_3
       56, 'LimbicA_TempPole_4 L',     [  255    0    0]; ...   % 17Networks_LH_LimbicA_TempPole_4
       57, 'ContA_Temp_1 L',           [  102  102  255]; ...   % 17Networks_LH_ContA_Temp_1
       58, 'ContA_IPS_1 L',            [  102  102  255]; ...   % 17Networks_LH_ContA_IPS_1
       59, 'ContA_IPS_2 L',            [  102  102  255]; ...   % 17Networks_LH_ContA_IPS_2
       60, 'ContA_IPS_3 L',            [  102  102  255]; ...   % 17Networks_LH_ContA_IPS_3
       61, 'ContA_PFCd_1 L',           [  102  102  255]; ...   % 17Networks_LH_ContA_PFCd_1
       62, 'ContA_PFClv_1 L',          [  102  102  255]; ...   % 17Networks_LH_ContA_PFClv_1
       63, 'ContA_PFCl_1 L',           [  102  102  255]; ...   % 17Networks_LH_ContA_PFCl_1
       64, 'ContA_PFCl_2 L',           [  102  102  255]; ...   % 17Networks_LH_ContA_PFCl_2
       65, 'ContA_PFCl_3 L',           [  102  102  255]; ...   % 17Networks_LH_ContA_PFCl_3
       66, 'ContA_Cingm_1 L',          [  102  102  255]; ...   % 17Networks_LH_ContA_Cingm_1
       67, 'ContB_Temp_1 L',           [  255  177  100]; ...   % 17Networks_LH_ContB_Temp_1
       68, 'ContB_IPL_1 L',            [  255  177  100]; ...   % 17Networks_LH_ContB_IPL_1
       69, 'ContB_PFCl_1 L',           [  255  177  100]; ...   % 17Networks_LH_ContB_PFCl_1
       70, 'ContB_PFClv_1 L',          [  255  177  100]; ...   % 17Networks_LH_ContB_PFClv_1
       71, 'ContB_PFClv_2 L',          [  255  177  100]; ...   % 17Networks_LH_ContB_PFClv_2
       72, 'ContC_pCun_1 L',           [    0  255  255]; ...   % 17Networks_LH_ContC_pCun_1
       73, 'ContC_pCun_2 L',           [    0  255  255]; ...   % 17Networks_LH_ContC_pCun_2
       74, 'ContC_Cingp_1 L',          [    0  255  255]; ...   % 17Networks_LH_ContC_Cingp_1
       75, 'DefaultA_IPL_1 L',         [  255    0  255]; ...   % 17Networks_LH_DefaultA_IPL_1
       76, 'DefaultA_PFCd_1 L',        [  255    0  255]; ...   % 17Networks_LH_DefaultA_PFCd_1
       77, 'DefaultA_pCunPCC_1 L',     [  255    0  255]; ...   % 17Networks_LH_DefaultA_pCunPCC_1
       78, 'DefaultA_pCunPCC_2 L',     [  255    0  255]; ...   % 17Networks_LH_DefaultA_pCunPCC_2
       79, 'DefaultA_pCunPCC_3 L',     [  255    0  255]; ...   % 17Networks_LH_DefaultA_pCunPCC_3
       80, 'DefaultA_PFCm_1 L',        [  255    0  255]; ...   % 17Networks_LH_DefaultA_PFCm_1
       81, 'DefaultA_PFCm_2 L',        [  255    0  255]; ...   % 17Networks_LH_DefaultA_PFCm_2
       82, 'DefaultA_PFCm_3 L',        [  255    0  255]; ...   % 17Networks_LH_DefaultA_PFCm_3
       83, 'DefaultB_Temp_1 L',        [  102    0    0]; ...   % 17Networks_LH_DefaultB_Temp_1
       84, 'DefaultB_Temp_2 L',        [  102    0    0]; ...   % 17Networks_LH_DefaultB_Temp_2
       85, 'DefaultB_Temp_3 L',        [  102    0    0]; ...   % 17Networks_LH_DefaultB_Temp_3
       86, 'DefaultB_Temp_4 L',        [  102    0    0]; ...   % 17Networks_LH_DefaultB_Temp_4
       87, 'DefaultB_IPL_1 L',         [  102    0    0]; ...   % 17Networks_LH_DefaultB_IPL_1
       88, 'DefaultB_PFCd_1 L',        [  102    0    0]; ...   % 17Networks_LH_DefaultB_PFCd_1
       89, 'DefaultB_PFCd_2 L',        [  102    0    0]; ...   % 17Networks_LH_DefaultB_PFCd_2
       90, 'DefaultB_PFCd_3 L',        [  102    0    0]; ...   % 17Networks_LH_DefaultB_PFCd_3
       91, 'DefaultB_PFCd_4 L',        [  102    0    0]; ...   % 17Networks_LH_DefaultB_PFCd_4
       92, 'DefaultB_PFCv_1 L',        [  102    0    0]; ...   % 17Networks_LH_DefaultB_PFCv_1
       93, 'DefaultB_PFCv_2 L',        [  102    0    0]; ...   % 17Networks_LH_DefaultB_PFCv_2
       94, 'DefaultB_PFCv_3 L',        [  102    0    0]; ...   % 17Networks_LH_DefaultB_PFCv_3
       95, 'DefaultB_PFCv_4 L',        [  102    0    0]; ...   % 17Networks_LH_DefaultB_PFCv_4
       96, 'DefaultC_IPL_1 L',         [    0  102    0]; ...   % 17Networks_LH_DefaultC_IPL_1
       97, 'DefaultC_Rsp_1 L',         [    0  102    0]; ...   % 17Networks_LH_DefaultC_Rsp_1
       98, 'DefaultC_PHC_1 L',         [    0  102    0]; ...   % 17Networks_LH_DefaultC_PHC_1
       99, 'TempPar_1 L',              [  255  215    0]; ...   % 17Networks_LH_TempPar_1
      100, 'TempPar_2 L',              [  255  215    0]; ...   % 17Networks_LH_TempPar_2
      101, 'VisCent_ExStr_1 R',        [  255    0    0]; ...   % 17Networks_RH_VisCent_ExStr_1
      102, 'VisCent_ExStr_2 R',        [  255    0    0]; ...   % 17Networks_RH_VisCent_ExStr_2
      103, 'VisCent_Striate_1 R',      [  255    0    0]; ...   % 17Networks_RH_VisCent_Striate_1
      104, 'VisCent_ExStr_3 R',        [  255    0    0]; ...   % 17Networks_RH_VisCent_ExStr_3
      105, 'VisCent_ExStr_4 R',        [  255    0    0]; ...   % 17Networks_RH_VisCent_ExStr_4
      106, 'VisCent_ExStr_5 R',        [  255    0    0]; ...   % 17Networks_RH_VisCent_ExStr_5
      107, 'VisPeri_ExStrInf_1 R',     [  102  102  255]; ...   % 17Networks_RH_VisPeri_ExStrInf_1
      108, 'VisPeri_ExStrInf_2 R',     [  102  102  255]; ...   % 17Networks_RH_VisPeri_ExStrInf_2
      109, 'VisPeri_StriCal_1 R',      [  102  102  255]; ...   % 17Networks_RH_VisPeri_StriCal_1
      110, 'VisPeri_ExStrSup_1 R',     [  102  102  255]; ...   % 17Networks_RH_VisPeri_ExStrSup_1
      111, 'VisPeri_ExStrSup_2 R',     [  102  102  255]; ...   % 17Networks_RH_VisPeri_ExStrSup_2
      112, 'VisPeri_ExStrSup_3 R',     [  102  102  255]; ...   % 17Networks_RH_VisPeri_ExStrSup_3
      113, 'SomMotA_1 R',              [  255  177  100]; ...   % 17Networks_RH_SomMotA_1
      114, 'SomMotA_2 R',              [  255  177  100]; ...   % 17Networks_RH_SomMotA_2
      115, 'SomMotA_3 R',              [  255  177  100]; ...   % 17Networks_RH_SomMotA_3
      116, 'SomMotA_4 R',              [  255  177  100]; ...   % 17Networks_RH_SomMotA_4
      117, 'SomMotA_5 R',              [  255  177  100]; ...   % 17Networks_RH_SomMotA_5
      118, 'SomMotA_6 R',              [  255  177  100]; ...   % 17Networks_RH_SomMotA_6
      119, 'SomMotA_7 R',              [  255  177  100]; ...   % 17Networks_RH_SomMotA_7
      120, 'SomMotA_8 R',              [  255  177  100]; ...   % 17Networks_RH_SomMotA_8
      121, 'SomMotA_9 R',              [  255  177  100]; ...   % 17Networks_RH_SomMotA_9
      122, 'SomMotA_10 R',             [  255  177  100]; ...   % 17Networks_RH_SomMotA_10
      123, 'SomMotA_11 R',             [  255  177  100]; ...   % 17Networks_RH_SomMotA_11
      124, 'SomMotB_Aud_1 R',          [    0  255  255]; ...   % 17Networks_RH_SomMotB_Aud_1
      125, 'SomMotB_Aud_2 R',          [    0  255  255]; ...   % 17Networks_RH_SomMotB_Aud_2
      126, 'SomMotB_S2_1 R',           [    0  255  255]; ...   % 17Networks_RH_SomMotB_S2_1
      127, 'SomMotB_S2_2 R',           [    0  255  255]; ...   % 17Networks_RH_SomMotB_S2_2
      128, 'SomMotB_S2_3 R',           [    0  255  255]; ...   % 17Networks_RH_SomMotB_S2_3
      129, 'SomMotB_S2_4 R',           [    0  255  255]; ...   % 17Networks_RH_SomMotB_S2_4
      130, 'SomMotB_Cent_1 R',         [    0  255  255]; ...   % 17Networks_RH_SomMotB_Cent_1
      131, 'DorsAttnA_TempOcc_1 R',    [  255    0  255]; ...   % 17Networks_RH_DorsAttnA_TempOcc_1
      132, 'DorsAttnA_ParOcc_1 R',     [  255    0  255]; ...   % 17Networks_RH_DorsAttnA_ParOcc_1
      133, 'DorsAttnA_SPL_1 R',        [  255    0  255]; ...   % 17Networks_RH_DorsAttnA_SPL_1
      134, 'DorsAttnA_SPL_2 R',        [  255    0  255]; ...   % 17Networks_RH_DorsAttnA_SPL_2
      135, 'DorsAttnA_SPL_3 R',        [  255    0  255]; ...   % 17Networks_RH_DorsAttnA_SPL_3
      136, 'DorsAttnA_SPL_4 R',        [  255    0  255]; ...   % 17Networks_RH_DorsAttnA_SPL_4
      137, 'DorsAttnB_PostC_1 R',      [  102    0    0]; ...   % 17Networks_RH_DorsAttnB_PostC_1
      138, 'DorsAttnB_PostC_2 R',      [  102    0    0]; ...   % 17Networks_RH_DorsAttnB_PostC_2
      139, 'DorsAttnB_PostC_3 R',      [  102    0    0]; ...   % 17Networks_RH_DorsAttnB_PostC_3
      140, 'DorsAttnB_PostC_4 R',      [  102    0    0]; ...   % 17Networks_RH_DorsAttnB_PostC_4
      141, 'DorsAttnB_FEF_1 R',        [  102    0    0]; ...   % 17Networks_RH_DorsAttnB_FEF_1
      142, 'SalVentAttnA_ParOper_1 R', [    0  102    0]; ...   % 17Networks_RH_SalVentAttnA_ParOper_1
      143, 'SalVentAttnA_PrC_1 R',     [    0  102    0]; ...   % 17Networks_RH_SalVentAttnA_PrC_1
      144, 'SalVentAttnA_Ins_1 R',     [    0  102    0]; ...   % 17Networks_RH_SalVentAttnA_Ins_1
      145, 'SalVentAttnA_Ins_2 R',     [    0  102    0]; ...   % 17Networks_RH_SalVentAttnA_Ins_2
      146, 'SalVentAttnA_FrOper_1 R',  [    0  102    0]; ...   % 17Networks_RH_SalVentAttnA_FrOper_1
      147, 'SalVentAttnA_FrMed_1 R',   [    0  102    0]; ...   % 17Networks_RH_SalVentAttnA_FrMed_1
      148, 'SalVentAttnA_ParMed_1 R',  [    0  102    0]; ...   % 17Networks_RH_SalVentAttnA_ParMed_1
      149, 'SalVentAttnA_ParMed_2 R',  [    0  102    0]; ...   % 17Networks_RH_SalVentAttnA_ParMed_2
      150, 'SalVentAttnA_FrMed_2 R',   [    0  102    0]; ...   % 17Networks_RH_SalVentAttnA_FrMed_2
      151, 'SalVentAttnB_IPL_1 R',     [  255  215    0]; ...   % 17Networks_RH_SalVentAttnB_IPL_1
      152, 'SalVentAttnB_PFClv_1 R',   [  255  215    0]; ...   % 17Networks_RH_SalVentAttnB_PFClv_1
      153, 'SalVentAttnB_PFCl_1 R',    [  255  215    0]; ...   % 17Networks_RH_SalVentAttnB_PFCl_1
      154, 'SalVentAttnB_Ins_1 R',     [  255  215    0]; ...   % 17Networks_RH_SalVentAttnB_Ins_1
      155, 'SalVentAttnB_Ins_2 R',     [  255  215    0]; ...   % 17Networks_RH_SalVentAttnB_Ins_2
      156, 'SalVentAttnB_PFCmp_1 R',   [  255  215    0]; ...   % 17Networks_RH_SalVentAttnB_PFCmp_1
      157, 'LimbicB_OFC_1 R',          [    0  204    0]; ...   % 17Networks_RH_LimbicB_OFC_1
      158, 'LimbicB_OFC_2 R',          [    0  204    0]; ...   % 17Networks_RH_LimbicB_OFC_2
      159, 'LimbicB_OFC_3 R',          [    0  204    0]; ...   % 17Networks_RH_LimbicB_OFC_3
      160, 'LimbicB_OFC_4 R',          [    0  204    0]; ...   % 17Networks_RH_LimbicB_OFC_4
      161, 'LimbicA_TempPole_1 R',     [  255    0    0]; ...   % 17Networks_RH_LimbicA_TempPole_1
      162, 'LimbicA_TempPole_2 R',     [  255    0    0]; ...   % 17Networks_RH_LimbicA_TempPole_2
      163, 'LimbicA_TempPole_3 R',     [  255    0    0]; ...   % 17Networks_RH_LimbicA_TempPole_3
      164, 'LimbicA_TempPole_4 R',     [  255    0    0]; ...   % 17Networks_RH_LimbicA_TempPole_4
      165, 'ContA_IPS_1 R',            [  102  102  255]; ...   % 17Networks_RH_ContA_IPS_1
      166, 'ContA_IPS_2 R',            [  102  102  255]; ...   % 17Networks_RH_ContA_IPS_2
      167, 'ContA_PFCd_1 R',           [  102  102  255]; ...   % 17Networks_RH_ContA_PFCd_1
      168, 'ContA_PFCl_1 R',           [  102  102  255]; ...   % 17Networks_RH_ContA_PFCl_1
      169, 'ContA_PFCl_2 R',           [  102  102  255]; ...   % 17Networks_RH_ContA_PFCl_2
      170, 'ContA_Cingm_1 R',          [  102  102  255]; ...   % 17Networks_RH_ContA_Cingm_1
      171, 'ContB_Temp_1 R',           [  255  177  100]; ...   % 17Networks_RH_ContB_Temp_1
      172, 'ContB_Temp_2 R',           [  255  177  100]; ...   % 17Networks_RH_ContB_Temp_2
      173, 'ContB_IPL_1 R',            [  255  177  100]; ...   % 17Networks_RH_ContB_IPL_1
      174, 'ContB_IPL_2 R',            [  255  177  100]; ...   % 17Networks_RH_ContB_IPL_2
      175, 'ContB_PFCld_1 R',          [  255  177  100]; ...   % 17Networks_RH_ContB_PFCld_1
      176, 'ContB_PFCld_2 R',          [  255  177  100]; ...   % 17Networks_RH_ContB_PFCld_2
      177, 'ContB_PFClv_1 R',          [  255  177  100]; ...   % 17Networks_RH_ContB_PFClv_1
      178, 'ContB_PFClv_2 R',          [  255  177  100]; ...   % 17Networks_RH_ContB_PFClv_2
      179, 'ContB_PFCmp_1 R',          [  255  177  100]; ...   % 17Networks_RH_ContB_PFCmp_1
      180, 'ContB_PFCld_3 R',          [  255  177  100]; ...   % 17Networks_RH_ContB_PFCld_3
      181, 'ContC_pCun_1 R',           [    0  255  255]; ...   % 17Networks_RH_ContC_pCun_1
      182, 'ContC_pCun_2 R',           [    0  255  255]; ...   % 17Networks_RH_ContC_pCun_2
      183, 'ContC_Cingp_1 R',          [    0  255  255]; ...   % 17Networks_RH_ContC_Cingp_1
      184, 'DefaultA_IPL_1 R',         [  255    0  255]; ...   % 17Networks_RH_DefaultA_IPL_1
      185, 'DefaultA_PFCd_1 R',        [  255    0  255]; ...   % 17Networks_RH_DefaultA_PFCd_1
      186, 'DefaultA_pCunPCC_1 R',     [  255    0  255]; ...   % 17Networks_RH_DefaultA_pCunPCC_1
      187, 'DefaultA_PFCm_1 R',        [  255    0  255]; ...   % 17Networks_RH_DefaultA_PFCm_1
      188, 'DefaultA_PFCm_2 R',        [  255    0  255]; ...   % 17Networks_RH_DefaultA_PFCm_2
      189, 'DefaultA_PFCm_3 R',        [  255    0  255]; ...   % 17Networks_RH_DefaultA_PFCm_3
      190, 'DefaultB_Temp_1 R',        [  102    0    0]; ...   % 17Networks_RH_DefaultB_Temp_1
      191, 'DefaultB_AntTemp_1 R',     [  102    0    0]; ...   % 17Networks_RH_DefaultB_AntTemp_1
      192, 'DefaultB_PFCd_1 R',        [  102    0    0]; ...   % 17Networks_RH_DefaultB_PFCd_1
      193, 'DefaultB_PFCv_1 R',        [  102    0    0]; ...   % 17Networks_RH_DefaultB_PFCv_1
      194, 'DefaultC_IPL_1 R',         [    0  102    0]; ...   % 17Networks_RH_DefaultC_IPL_1
      195, 'DefaultC_Rsp_1 R',         [    0  102    0]; ...   % 17Networks_RH_DefaultC_Rsp_1
      196, 'DefaultC_PHC_1 R',         [    0  102    0]; ...   % 17Networks_RH_DefaultC_PHC_1
      197, 'TempPar_1 R',              [  255  215    0]; ...   % 17Networks_RH_TempPar_1
      198, 'TempPar_2 R',              [  255  215    0]; ...   % 17Networks_RH_TempPar_2
      199, 'TempPar_3 R',              [  255  215    0]; ...   % 17Networks_RH_TempPar_3
      200, 'TempPar_4 R',              [  255  215    0]; ...   % 17Networks_RH_TempPar_4
};
        