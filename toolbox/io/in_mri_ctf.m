function MRI = in_mri_ctf(MriFile, ByteOrder)
% Proper read of CTF .mri file format.
%
% USAGE:  in_mri_ctf(MriFile)
%         in_mri_ctf(MriFile, ByteOrder)
% INPUT:
%     - MriFile   : full path to a MRI file
%     - ByteOrder : {'l' for little endian, or 'b' for big endian}
%                   Default : auto-detect
% OUTPUT: 
%     - MRI       : Standard brainstorm structure for MRI volumes
%
% FORMAT:
%     CTF MRI File Version 2.1:
%     The CTF MRI File format consists of a binary file with a
%     1,028 byte header. The MRI data can be in 8-bit (unsigned character) 
%     or 16-bit (unsigned short integer) format and consists of 256 x 256 
%     pixel slices, stored as 256 contiguous sagittal slices from left to 
%     right (or right to left if head orientation is "left-on-right"). Each
%     slice is stored as individual pixels starting at the top left corner 
%     and scanning downwards row by row. Therefore the coronal position is
%     fastest changing, axial position second fastest changing and sagittal
%     position slowest changing value in the file, always in the positive 
%     direction for each axis (see section on Head Coordinate System for
%     axis definitions). By default CTF MRI files have the file extension ".mri"
%
%     CTF MRI File Version 4.1
%     The CTF MRI File format consists of a binary file with a
%     3,072 byte header. The MRI data can be in 8-bit (unsigned character) 
%     or 16-bit (unsigned short integer) format and consists of 256 x 256 
%     pixel slices, stored as 256 contiguous sagittal slices from left to 
%     right (or right to left if head orientation is "left-on-right"). Each
%     slice is stored as individual pixels starting at the top left corner 
%     and scanning downwards row by row. Therefore the coronal position is
%     fastest changing, axial position second fastest changing and sagittal
%     position slowest changing value in the file, always in the positive 
%     direction for each axis (see section on Head Coordinate System for
%     axis definitions). By default CTF MRI files have the file extension ".mri"
%
%     see below the others tag which may be use in mri file V4 for future
%     use of Brainstorm (see 'FileFormats' chapter page 90 of ctf
%     documentation for more informations).
%         _CTFMRI_UID                      string
%         _CTFMRI _INTERPOLATEDFLAG        short
%         _CTFMRI _TRANSFORMMATRIX         string
%         _CTFMRI_COMMENT                  string
% 
%         _PATIENT_NAME                    string
%         _PATIENT_BIRTHDAY                string
%         _PATIENT_SEX                     short
% 
%         _STUDY_ID                        string
%         _STUDY_DATE                      string
%         _STUDY_TIME                      string
%         _STUDY_DESCRIPTION               string
%         _STUDY_ACCESSIONNUMBER           string
% 
%         _SERIES_DATE                     string
%         _SERIES_TIME                     string
%         _EQUIP_MODEL                     string
% 
%         _IMAGE_REFERENCEDUID             string
%         _REFERENCE_UID                   string
%         _REFERENCE_INDICATOR             string
%         _IMAGEPLANE_LOCATION             string
%         _IMAGEPIXEL_INTERPRETATION       string
%         _MRIMAGE_SEQUENCENAME            string
%         _MRIMAGE_SCANNINGSSEQUENCE       string
%         _MRIMAGE_SEQUENCEVARIANT         string
%         _MRIMAGE_AVERAGES                string
%         _CTIMAGE_RESCALEINTERCEPT        string
%         _CTIMAGE_RESCALESLOPE            string
% 
%         _VOILUT_WINDOWWIDTH              double
%         _VOILUT_WINDOWCENTER             double
%         _SPECIFICCHARSET                 string
% 
%         _DICOMSOURCE_HASVALIDIMAGE       int
%         _DICOMSOURCE_NUMBER_SLICES       unsigned short
%         _DICOMSOURCE_NUMBER_ROWS         unsigned short
%         _DICOMSOURCE_NUMBER_COLUMNS      unsigned short
%         _DICOMSOURCE_SLICE_SPACING       double
%         _DICOMSOURCE_SLICE_THICKNESS     double
%         _DICOMSOURCE_ROW_SPACING         double
%         _DICOMSOURCE_COLUMN_SPACING      double
%         _DICOMSOURCE_ROW_ORIENTATION     CString
%         _DICOMSOURCE_COLUMN_ORIENTATION  CString
%         _DICOMSOURCE_LOCATION_GAP        CString
%         _DICOMSOURCE_SLICE_LOCATION      CString
%         _DICOMSOURCE_CTF_TO_SOURCE_SLICE CString
%
% SEE ALSO: in_mri

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
% Authors: Francois Tadel, 2008
% Modified by Jonathan Richer, CERMEP, 2009 (Adaptation for MRI V4 file)

% Parse inputs
if (nargin < 2)
    try 
        MRI = in_mri_ctf(MriFile, 'b');
    catch
        MRI = in_mri_ctf(MriFile, 'l');
    end
    return;
end
MRI = [];


%% ===== READ FILE =====
% Open file
file = fopen(MriFile, 'rb', ByteOrder); 
if file < 1
    error('Cannot open file : "%s"', MriFile);
end

% Read version
Header.identifierversion = fscanf(file,'%c',32);

%% ==== MRI file version 4.1 loaded ====
if (strncmp(Header.identifierversion,'WS1_',4))
    
    % == READ HEADER V4 =
    fseek(file,4,'bof'); % put the cursor next the identifier version
    [all_tag] = read_mri_CTFV4(file); % read all informations of header

    % We select only interesting informations of header V4
    % Header : General information
    Header.identifierString = Header.identifierversion;
    Header.imageSize = all_tag(locate_tag_CTFV4(all_tag,'_CTFMRI_SIZE')).value;
    Header.dataSize = all_tag(locate_tag_CTFV4(all_tag,'_CTFMRI_DATASIZE')).value;
    Header.clippingRange = 32767;
    Header.imageOrientation = all_tag(locate_tag_CTFV4(all_tag,'_IMAGEPLANE_ORIENTATION')).value;
    
    format long;
    Header_temp = textscan(all_tag(locate_tag_CTFV4(all_tag,'_CTFMRI_MMPERPIXEL')).value,'%f','delimiter','\\');
    Header.mmPerPixel_sagittal = Header_temp{1}(1);
    Header.mmPerPixel_coronal = Header_temp{1}(2);
    Header.mmPerPixel_axial = Header_temp{1}(3);

    % Header : Head Model Info
    % coordinate of Nasion
    Header_temp = textscan(all_tag(locate_tag_CTFV4(all_tag,'_HDM_NASION')).value,'%f','delimiter','\\');
    Header.HeadModel_Info.Nasion_Sag = Header_temp{1}(1);
    Header.HeadModel_Info.Nasion_Cor = Header_temp{1}(2);
    Header.HeadModel_Info.Nasion_Axi = Header_temp{1}(3);


    % coordinate of Left Ear
    Header_temp = textscan(all_tag(locate_tag_CTFV4(all_tag,'_HDM_LEFTEAR')).value,'%f','delimiter','\\');
    Header.HeadModel_Info.LeftEar_Sag = Header_temp{1}(1);
    Header.HeadModel_Info.LeftEar_Cor = Header_temp{1}(2);
    Header.HeadModel_Info.LeftEar_Axi = Header_temp{1}(3);
 
 
    % coordinate of Right Ear
    Header_temp = textscan(all_tag(locate_tag_CTFV4(all_tag,'_HDM_RIGHTEAR')).value,'%f','delimiter','\\');
    Header.HeadModel_Info.RightEar_Sag = Header_temp{1}(1);
    Header.HeadModel_Info.RightEar_Cor = Header_temp{1}(2);
    Header.HeadModel_Info.RightEar_Axi = Header_temp{1}(3);
 
    % coordinate of default sphere
    Header_temp = textscan(all_tag(locate_tag_CTFV4(all_tag,'_HDM_DEFAULTSPHERE')).value,'%f','delimiter','\\');
    HeadModel_Info.defaultSphereX = Header_temp{1}(1);
    HeadModel_Info.defaultSphereY = Header_temp{1}(2);
    HeadModel_Info.defaultSphereZ = Header_temp{1}(3);
    HeadModel_Info.defaultSphereRadius= Header_temp{1}(4);
    format short;

    % Header : Image Info
    modality = all_tag(locate_tag_CTFV4(all_tag,'_SERIES_MODALITY')).value;
    switch modality 
        case 'MR'
        Header.Image_Info.modality = 0;
        case 'CT'
        Header.Image_Info.modality = 1;
        case 'PET'
        Header.Image_Info.modality = 2;
        case 'SPECT'
        Header.Image_Info.modality = 3;
        otherwise 
        Header.Image_Info.modality = 4;
    end
    Header.Image_Info.manufacturerName = ...
        all_tag(locate_tag_CTFV4(all_tag,'_EQUIP_MANUFACTURER')).value;
    Header.Image_Info.instituteName = ...
        all_tag(locate_tag_CTFV4(all_tag,'_EQUIP_INSTITUTION')).value;
    Header.Image_Info.patientID = ...
        all_tag(locate_tag_CTFV4(all_tag,'_PATIENT_ID')).value;
    Header.Image_Info.dateAndTime = ...
        all_tag(locate_tag_CTFV4(all_tag,'_STUDY_DATETIME')).value;
    Header.Image_Info.scanType = ...
        all_tag(locate_tag_CTFV4(all_tag,'_SERIES_DESCRIPTION')).value;
    Header.Image_Info.contrastAgent = ''; % empty
    Header.Image_Info.imagedNucleus = ...
        all_tag(locate_tag_CTFV4(all_tag,'_MRIMAGE_IMAGEDNUCLEUS')).value;
    Header.Image_Info.Frequency = str2double(...
        all_tag(locate_tag_CTFV4(all_tag,'_MRIMAGE_FREQUENCY')).value);
    Header.Image_Info.FieldStrengh = str2double(...
        all_tag(locate_tag_CTFV4(all_tag,'_MRIMAGE_FIELDSTRENGTH')).value);
    Header.Image_Info.EchoTime = str2double(...
        all_tag(locate_tag_CTFV4(all_tag,'_MRIMAGE_ECHOTIME')).value);
    Header.Image_Info.RepetitionTime = str2double(...
        all_tag(locate_tag_CTFV4(all_tag,'_MRIMAGE_REPETITIONTIME')).value);
    Header.Image_Info.InversionTime = str2double(...
        all_tag(locate_tag_CTFV4(all_tag,'_MRIMAGE_INVERSIONTIME')).value);
    Header.Image_Info.FlipAngle = str2double(...
        all_tag(locate_tag_CTFV4(all_tag,'_MRIMAGE_FLIPANGLE')).value);
    Header.Image_Info.NoExcitations = []; % empty
    Header.Image_Info.NoAcquisitions = []; % empty
    Header.Image_Info.commentString = ...
        all_tag(locate_tag_CTFV4(all_tag,'_STUDY_COMMENTS')).value;
    Header.Image_Info.forFutureUse = ''; % empty
    
    format long;
    % Header : Origin
    Header_temp = textscan(all_tag(locate_tag_CTFV4(all_tag,'_HDM_HEADORIGIN')).value,'%f','delimiter','\\');
    Header.headOrigin_sagittal = Header_temp{1}(1);
    Header.headOrigin_coronal = Header_temp{1}(2);
    Header.headOrigin_axial = Header_temp{1}(3);
    
    Header_temp = textscan(all_tag(locate_tag_CTFV4(all_tag,'_CTFMRI_ROTATE')).value,'%f','delimiter','\\');
    Header.rotate_sagittal = Header_temp{1}(1);
    Header.rotate_coronal = Header_temp{1}(2);
    Header.rotate_axial = Header_temp{1}(3);
    format short; 
    
    Header.orthogonalFlag = all_tag(locate_tag_CTFV4(all_tag,'_CTFMRI_ORTHOGONALFLAG')).value;
    Header.unused = '';

    % ===== READ MRI VOLUME =====
    % Check header integrity before going on
    if isempty(Header.dataSize) || ((Header.dataSize ~= 1) && (Header.dataSize ~= 2))
        bst_error(['Unrecognized data format.' 10 ...
            'Try switching the byte order: ' 10 ...
            '(Menu Options>Set preferences...>Little/Big endian).']);
        return
    end

    % build an isotropic cubic mri volume with sclices data
    MRI.Cube = int16(prod([Header.imageSize*Header.imageSize,Header.imageSize]));
    cube = zeros(Header.imageSize*Header.imageSize,Header.imageSize,1,'uint16');
    for  sagittal_num = 1: Header.imageSize
        [s_tag] = sprintf('_CTFMRI_SLICE_DATA#%05d',sagittal_num);
        cube(:,sagittal_num) = all_tag(locate_tag_CTFV4(all_tag,s_tag)).value;
    end
    MRI.Cube = reshape(cube,Header.imageSize,Header.imageSize,Header.imageSize);

    %% ===== Convert to Brainstorm format =====
    MRI.Voxsize = [Header.mmPerPixel_sagittal,...
                    Header.mmPerPixel_coronal,...
                    Header.mmPerPixel_axial];

    % PermVect: Permutation vector to apply to the original cube
    % and associated parameters to get the MR volume in the proper 
    % orientation of the MRViwer and Brainstorm format.
    permVect    = [3,1,2]; 
    MRI.Cube    = permute(MRI.Cube,permVect);
    MRI.Voxsize = MRI.Voxsize(permVect);
    MRI.Cube    = MRI.Cube(:, end:-1:1, end:-1:1);

    % ===== FIDUCIALS =====
    % If defined, fill-out SCS information
    try
        MRI.SCS.NAS =... % Nasion
            [Header.HeadModel_Info.Nasion_Sag,...
            size(MRI.Cube,2) - Header.HeadModel_Info.Nasion_Cor,...
            size(MRI.Cube,3) - Header.HeadModel_Info.Nasion_Axi] ...
            .* MRI.Voxsize;
        
        MRI.SCS.LPA =... % Left ear
            [Header.HeadModel_Info.LeftEar_Sag,...
            size(MRI.Cube,2) - Header.HeadModel_Info.LeftEar_Cor,...
            size(MRI.Cube,3) - Header.HeadModel_Info.LeftEar_Axi]...
            .* MRI.Voxsize;
        
        MRI.SCS.RPA =... % Right ear
            [Header.HeadModel_Info.RightEar_Sag,...
            size(MRI.Cube,2) - Header.HeadModel_Info.RightEar_Cor,...
            size(MRI.Cube,3) - Header.HeadModel_Info.RightEar_Axi]...
            .* MRI.Voxsize;
        
    catch
        error('Brainstorm:NoFiducials', 'Cannot read fiducials.');
    end

%% ==== MRI file version 2.2 loaded ====
elseif(strncmp(Header.identifierversion,'CTF_MRI_FORMAT VER 2.2',22))
    fseek(file,32,'bof'); % put the cursor next the identifier version
    
    % == READ HEADER ===
    % Header : Volume description
    Header.identifierString    = Header.identifierversion; 
    Header.imageSize           = fread(file,1,'short');
    Header.dataSize            = fread(file,1,'short');
    Header.clippingRange       = fread(file,1,'short');
    Header.imageOrientation    = fread(file,1,'short');
    Header.mmPerPixel_sagittal = fread(file,1,'float32');
    Header.mmPerPixel_coronal  = fread(file,1,'float32');
    Header.mmPerPixel_axial    = fread(file,1,'float32');

    % Header : Head Model Info
    Header.HeadModel_Info.Nasion_Sag = fread(file,1,'short');
    Header.HeadModel_Info.Nasion_Cor = fread(file,1,'short');
    Header.HeadModel_Info.Nasion_Axi = fread(file,1,'short');
    Header.HeadModel_Info.LeftEar_Sag = fread(file,1,'short');
    Header.HeadModel_Info.LeftEar_Cor = fread(file,1,'short');
    Header.HeadModel_Info.LeftEar_Axi = fread(file,1,'short');
    Header.HeadModel_Info.RightEar_Sag = fread(file,1,'short');
    Header.HeadModel_Info.RightEar_Cor = fread(file,1,'short');
    Header.HeadModel_Info.RightEar_Axi = fread(file,1,'short');
    Header.HeadModel_Info.defaultSphereX= fread(file,1,'float32');
    Header.HeadModel_Info.defaultSphereY= fread(file,1,'float32');
    Header.HeadModel_Info.defaultSphereZ= fread(file,1,'float32');
    Header.HeadModel_Info.defaultSphereRadius= fread(file,1,'float32');

    % Header : Image Info
    Header.Image_Info.modality = fread(file,1,'short');
    Header.Image_Info.manufacturerName = fread(file,64,'char');
    Header.Image_Info.instituteName = fread(file,64,'char');
    Header.Image_Info.patientID = fread(file,32,'char');
    Header.Image_Info.dateAndTime = fread(file,32,'char');
    Header.Image_Info.scanType = fread(file,32,'char');
    Header.Image_Info.contrastAgent = fread(file,32,'char');
    Header.Image_Info.imagedNucleus = fread(file,32,'char');
    Header.Image_Info.Frequency = fread(file,1,'float32');
    Header.Image_Info.FieldStrengh = fread(file,1,'float32');
    Header.Image_Info.EchoTime = fread(file,1,'float32');
    Header.Image_Info.RepetitionTime = fread(file,1,'float32');
    Header.Image_Info.InversionTime = fread(file,1,'float32');
    Header.Image_Info.FlipAngle = fread(file,1,'float32');
    Header.Image_Info.NoExcitations = fread(file,1,'short');
    Header.Image_Info.NoAcquisitions = fread(file,1,'short');
    Header.Image_Info.commentString = fread(file,256,'char');
    Header.Image_Info.forFutureUse = fread(file,64,'char');

    % Header : Origin
    Header.headOrigin_sagittal = fread(file,1,'float32');
    Header.headOrigin_coronal = fread(file,1,'float32');
    Header.headOrigin_axial  = fread(file,1,'float32');

    Header.rotate_coronal = fread(file,1,'float32');
    Header.headOrigin_sagittal = fread(file,1,'float32');
    Header.headOrigin_axial  = fread(file,1,'float32');
    Header.orthogonalFlag = fread(file,1,'short');
    Header.unused = fread(file,272,'uchar');

    % Skip the whole header by padding to 1028
    fseek(file,1028,-1); 

    % === READ MRI VOLUME ==
    % Check header integrity before going on
    if isempty(Header.dataSize) || ((Header.dataSize~=1) && (Header.dataSize~=2))
        error(['Unrecognized data format.' 10 ...
            'Try switching the byte order: ' 10 ...
            '(Menu Options>Byte order>Little/Big endian).']);
    end
    if (Header.dataSize == 1) 
        DataClass = 'uchar';
    elseif (Header.dataSize == 2) 
        DataClass = 'ushort';
    end

    % Read the whole volume / store in a huge vector   
    MRI.Cube = int16(fread(file, prod([256 256 Header.imageSize]), DataClass)); 
    % Reshape it into a 3-D array.
    MRI.Cube = reshape(MRI.Cube, 256, 256, Header.imageSize); 
    % Close MRI file 
    fclose(file);

    %% ===== Convert to Brainstorm format =====
    MRI.Voxsize = [Header.mmPerPixel_sagittal,...
                    Header.mmPerPixel_coronal,...
                    Header.mmPerPixel_axial];

    %permVect: Permutation vector to apply to the original cube
    % and associated parameters to get the MR volume in the proper 
    % orientation of the MRViwer and Brainstorm format.
    permVect    = [3,1,2];
    MRI.Cube    = permute(MRI.Cube,permVect);
    MRI.Voxsize = MRI.Voxsize(permVect);
    MRI.Cube    = MRI.Cube(:, end:-1:1, end:-1:1);
    MRI.Header  = Header;
    
    % ===== FIDUCIALS =====
    % If defined, fill-out SCS information
    try
        MRI.SCS.NAS = ...
            [Header.HeadModel_Info.Nasion_Sag,...
            size(MRI.Cube,2) - Header.HeadModel_Info.Nasion_Cor,...
            size(MRI.Cube,3) - Header.HeadModel_Info.Nasion_Axi]...
            .* MRI.Voxsize;
        MRI.SCS.LPA =...
            [Header.HeadModel_Info.LeftEar_Sag,...
            size(MRI.Cube,2) - Header.HeadModel_Info.LeftEar_Cor,...
            size(MRI.Cube,3) - Header.HeadModel_Info.LeftEar_Axi]...
            .* MRI.Voxsize;
        MRI.SCS.RPA =...
            [Header.HeadModel_Info.RightEar_Sag,...
            size(MRI.Cube,2) - Header.HeadModel_Info.RightEar_Cor,...
            size(MRI.Cube,3) - Header.HeadModel_Info.RightEar_Axi]...
            .* MRI.Voxsize;
    catch
        error('Brainstorm:NoFiducials', 'Cannot read fiducials.');
    end

% if not MRI file V2 or V4 
else
    fclose(file);
    error('The file is not an mri CTF version 4.1');
end
end

% function to locate a tag among the 'header' chart
function [index] = locate_tag_CTFV4(header,tag)
    index = 1;
    while index <= size(header,2)
      if strcmp(header(index).label_text,tag) == true
          return;
      end
      index = index +1;
    end
    index = 0;
end

% function to read one tag and its value
function [header] = read_mri_CTFV4(file)
    
    item = 0;  end_of_file = 0; % init
    while end_of_file == 0

        [label_lenght] = fread(file,1,'int32','ieee-be');
        label_text = fscanf(file,'%c',label_lenght);

        % detect last dataof file
        if strcmp(label_text,'_CTFMRI_SLICE_DATA#00256') == true
            end_of_file = 1;
        end    

        value_type = fread(file,1,'uint32','ieee-be');
        if (value_type == 3 || value_type == 10)
            % binary or Cstring
            value_lenght = fread(file,1,'uint32','ieee-be');
        else
            % other and usefullness
            value_lenght = 0;
        end
        
        switch value_type
            case 3
                value = fread(file,value_lenght/2,'uint16','ieee-be');
            case 4 
                value = fread(file,1,'float64','ieee-be');
            case 5
                value = fread(file,1,'int32','ieee-be');
            case 6
                value = fread(file,1,'int16','ieee-be');
            case 7
                value = fread(file,1,'uint16','ieee-be');
            case 8
                value = fread(file,1,'uchar','ieee-be');
            case 9
                value = fscanf(file,'%c',32);
            case 10
                value = fscanf(file,'%c',value_lenght);
            case 14
                value = fread(file,1,'long','ieee-be');
            case 15
                value = fread(file,1,'ulong','ieee-be');
            case 16
                value = fread(file,1,'uint32','ieee-be');
            case 17
                value = fread(file,1,'int32','ieee-be');
            otherwise 
                value = 0;
        end

        item = item +1;

        % each header
        header(item).label_lenght = label_lenght;
        header(item).label_text = label_text;
        header(item).value_type = value_type;
        header(item).value_lenght = value_lenght;
        header(item).value = value;

    end
    fclose(file);
end