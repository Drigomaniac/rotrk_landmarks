function [TRKS_OUT] = rotrk_read(filePath, identifier, vol_data_untyped,specific_name)
%function [TRKS_OUT] = rotrk_read(filePath, identifier, vol_data_untyped,specific_name)
% Goal: To load .trk or *.trk.gz files
% Inputs:
%    filePath - Full path to *.trk or *.trk.gz file
%    identifier - This will get us the TRKS_OUT.filename ID if found. (also
%                 used to avoid warning or orientations 
%         *if inputted: 'no_warning' --> No warning in ORIENTATION
%         *if inputted: 'simple_read' --> Just reead header and trks (doest
%         no take into accounr sstr.vox_coord

%    vol_data_untyped - vol_data with accurate orientation!
%    specific_name - will give you a unique identifier for what
%                     this tract is (e.g. dot_fornix). Default: 'none'
%
% Outputs:
%    tract
%           tract.header - Header information from .trk file [struc]
%           tract.trk_name - (field will pass what specific_name is...)
%           tract.sstr - tract data structure array [1 x ntracts]
%           tract.sstr.nPoints - # of points in each streamline
%           tract.sstr.matrix  - XYZ coordinates (in mm) and associated scalars [nPoints x 3+nScalars]
%
%
%   Example:  temp_hippocing_lh = rotrk_read('my_TOI.trk', 'HAB_669', 'My_FA.nii', 'trkk'_Hippocampus');
%   Created by Rodrigo Perea Github: https://github.com/Drigomaniac adapted



if nargin < 3, error('Please provide at least 3 arguments as the nii_vol is needed for orientation purposes') ; end

if nargin < 4, specific_name='none' ; end

if ischar(vol_data_untyped)
    vol_data.filename={vol_data_untyped};
else
    vol_data=vol_data_untyped;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Make the necessary arguments of 'char' type
if iscell(filePath) ; filePath=cell2char_rdp(filePath); end
if iscell(identifier) ; identifier=cell2char_rdp(identifier); end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Make sure you are not sending gzippoed file. If so, unzip read and rezip
%and the end

%TRKS.trk.gz
[ ro_dirpath, ro_filename, ro_ext ] = fileparts(filePath);
if strcmp(ro_ext,'.gz')
    %disp(['Gunzipping...' filePath ]);
    system([ 'gunzip -f ' filePath] );
    filePath=[ro_dirpath filesep ro_filename ];
end

[ ronii_dirpath, ronii_filename, ronii_ext ] = fileparts(cell2char_rdp(vol_data.filename));
%VOLDATA.nii.gz
if strcmp(ronii_ext,'.gz')
    %disp(['Gunzipping...' vol_data.filename ]);
    system([ 'gunzip -f ' cell2char_rdp(vol_data.filename) ] );
    if strcmp(ronii_dirpath,'')
        ronii_dirpath='./';
    end
    vol_data.filename=[ronii_dirpath filesep ronii_filename ];
    ro_filename=vol_data.filename;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

% Parse in header
fid    = fopen(filePath, 'r');
header = get_header(fid);

header.specific_name = specific_name;
%Raw values of inversion (for orientation purposes)
raw_invertx = header.invert_x;
raw_inverty = header.invert_y;
raw_invertz = header.invert_z;
%MODIFY HEADER BASED ON RAW INVERSION
if raw_invertx ==1 %Change by reversing all if vol_data differs from tract!
    %Now changing parameters...
    header.invert_x=0;
    header.vox_to_ras(1,1) = -1*header.vox_to_ras(1,1);
    if header.voxel_order(1) == 'L'
        header.voxel_order(1) = 'R';
        header.pad2(1) = 'R';
    else
        header.voxel_order(1) = 'L';
        header.pad2(1) = 'L';
    end
end
if raw_inverty ==1
    header.invert_y=0;
    header.vox_to_ras(2,2) = -1*header.vox_to_ras(2,2);
    if header.voxel_order(2) == 'P'
        header.voxel_order(2) = 'A';
        header.pad2(2) = 'A';
    else
        header.voxel_order(2) = 'P';
        header.pad2(2) = 'P';
    end
end
if raw_invertz ==1
    header.invert_z=0;
    header.vox_to_ras(3,3) = -1*header.vox_to_ras(3,3);
    if header.voxel_order(3) == 'S'
        header.voxel_order(3) = 'A';
        header.pad2(3) = 'A';
    else
        header.voxel_order(3) = 'S';
        header.pad2(3) = 'S';
    end
end



%/~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
%Reading the vol_data orientation to find the same orientation...
if isstruct(vol_data)
    if iscell(vol_data.filename)
        tmp_vol=spm_vol(cell2char_rdp(vol_data.filename));
    else
        tmp_vol=spm_vol(vol_data.filename);
    end
    
else
    tmp_vol=spm_vol(vol_data);
end

%Gzip the niftii files now...
if strcmp(ronii_ext,'.gz') ;  system([ 'gzip ' ro_filename  ] ); end


%check if the orientation is the same (by looking at the multiplication of signs)
%if positive, then signs ('+' or both '-') are the same
%else, change...
flag_x=0;flag_y=0; flag_z=0;
warn=0;
if (tmp_vol.mat(1,1)*header.vox_to_ras(1,1)) < 0
    %PREVIOUS DEPRECATED CODE: ~(abs(tmp_vol.mat(1,1) - header.vox_to_ras(1,1))) < tolerance
    if ~strcmp(identifier,'no_warning')
        warn=1;
        %   display('Volume matrix in the x coordinate is not equal to the trk matrix. Flipping to fit same orientation')
        %warning('Double check orientation after using this!')
    end
    flag_x=-1;
    header.vox_to_ras(1,1) = -1*header.vox_to_ras(1,1);
end

if (tmp_vol.mat(2,2)*header.vox_to_ras(2,2)) < 0
    if ~strcmp(identifier,'no_warning')
        warn=1;
        %    display('Volume matrix in the y coordinate is not equal to the trk matrix. Flipping to fit same orientation')
    end
    flag_y=-1;
    header.vox_to_ras(2,2) = -1*header.vox_to_ras(2,2);
end

if (tmp_vol.mat(3,3)*header.vox_to_ras(3,3)) < 0
    if ~strcmp(identifier,'no_warning')
        warn=1;
        %   display('Volume matrix in the z coordinate is not equal to the trk matrix. Flipping to fit same orientation')
    end
    %warning('Double check orientation after using this!')
    flag_z=-1;
    header.vox_to_ras(3,3) = -1*header.vox_to_ras(3,3);
end

if warn==1
    % warning('Volume matrix in the xyz coordinate is not equal to the trk matrix. Flipping to fit same orientation')
    fprintf(' - (double check orientation after using this) - ')
end

%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~/

% Check for byte order
if header.hdr_size~=1000
    fclose(fid);
    fid    = fopen(filePath, 'r', 'b'); % Big endian for old PPCs
    header = get_header(fid);
end

if header.hdr_size~=1000, error('Header length is wrong. Make sure is gunzipped!'), end
%
% % Check orientation
% [tmp ix] = max(abs(header.image_orientation_patient(1:3)));
% [tmp iy] = max(abs(header.image_orientation_patient(4:6)));
% iz = 1:3;
% iz([ix iy]) = [];
ix=1; iy=2; iz=3;

% Fix volume dimensions to match the reported orientation.
header.dim        = header.dim([ix iy iz]);
header.voxel_size = header.voxel_size([ix iy iz]);

% Parse in body
if header.n_count > 0
    max_n_trks = header.n_count;
else
    % Unknown number of tracts; we'll just have to read until we run out.
    max_n_trks = inf;
end

%/~~~~~~~~~~~~~~~~
header.id=identifier;
%~~~~~~~~~~~~~~~~~~/


%Assing orientation orde
iTrk = 1;
fprintf('\nReading streamlines...');
while iTrk <= max_n_trks
    pts = fread(fid, 1, 'int');
    if feof(fid)
        break;
    end
    tracts(iTrk).nPoints = pts;
    tracts(iTrk).matrix  = fread(fid, [3+header.n_scalars, tracts(iTrk).nPoints], '*float')';
    if header.n_properties
        tracts(iTrk).props = fread(fid, header.n_properties, '*float');
    end
    
    coords = tracts(iTrk).matrix(:,1:3);
    
    %/~~~~~~~~~~~~~~~~~~~~
    %Code modified to make sure the order is correct!
    if flag_x < 0 %Change by reversing all if vol_data differs from tract!
        coords(:,ix) = header.dim(ix)*header.voxel_size(ix) - coords(:,ix);
    end
    if flag_y < 0
        coords(:,iy) = header.dim(iy)*header.voxel_size(iy) - coords(:,iy);
    end
    if flag_z < 0
        coords(:,iz) = header.dim(iz)*header.voxel_size(iz) - coords(:,iz);
    end
    %~~~~~~~~~~~~~~~~~~~~/
    tracts(iTrk).matrix(:,1:3) = coords;
    iTrk = iTrk + 1;
end
fprintf('done\n');

header.pad2=header.voxel_order;
if header.n_count == 0
    header.n_count = length(tracts);
end



    %MODIFY HEADER BASED ON ORIENTATION
    if flag_x < 0 %Change by reversing all if vol_data differs from tract!
        %Now changing parameters...
        header.invert_x=1;
        if header.voxel_order(1) == 'L'
            header.voxel_order(1) = 'R';
            header.pad2(1) = 'R';
        else
            header.voxel_order(1) = 'L';
            header.pad2(1) = 'L';
        end
    end
    if flag_y < 0
        header.invert_y=1;
        if header.voxel_order(2) == 'P'
            header.voxel_order(2) = 'A';
            header.pad2(2) = 'A';
        else
            header.voxel_order(2) = 'P';
            header.pad2(2) = 'P';
        end
    end
    if flag_z < 0
        header.invert_z=1;
        if header.voxel_order(3) == 'S'
            header.voxel_order(3) = 'A';
            header.pad2(3) = 'A';
        else
            header.voxel_order(3) = 'S';
            header.pad2(3) = 'S';
        end
    end

fclose(fid);
header.voxel_order=header.voxel_order;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%GZIPPING BACK IF NEEDED:
if strcmp(ro_ext,'.gz')
    %disp(['gzipping now...' filePath ])
    system(['gzip ' filePath] );
    filePath=[ filePath '.gz' ];
end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Here we deal with xyz coordinates in MNI voxel system (creating
%tract.sstr.vox_coord ) and removing repeats
TRKS_OUT.header=header;
%%These should be of a 'char' type:
TRKS_OUT.filename=fullfile(filePath);
TRKS_OUT.id=identifier;
if ~strcmp(specific_name,'none')
    TRKS_OUT.trk_name=specific_name;
end
if ~strcmp(identifier,'simple_read')
    for ii=1:size(tracts,2)
        pos=round(tracts(ii).matrix(:,1:3) ./ repmat(header.voxel_size, tracts(ii).nPoints,1));
        %pos=pos+1;
        %CHECKING FOR DUPLICATED:"
        posnew_idx=0;
        
        %REPLACE <1 index values with the lowest voxel space value (e.g. 1)
        neg_pos=find(pos<1) ; for gg=1:numel(neg_pos); pos(neg_pos(gg))=1 ; end
        
        %Same replacing but for extreme values (based of header.dim(x/y/z)
        extreme_x=find(pos(:,1)>=header.dim(1)) ; for gg=1:numel(extreme_x); pos(extreme_x(gg),1)=header.dim(1) ; end
        extreme_y=find(pos(:,2)>=header.dim(2)) ; for gg=1:numel(extreme_y); pos(extreme_y(gg),2)=header.dim(2) ; end
        extreme_z=find(pos(:,3)>=header.dim(3)) ; for gg=1:numel(extreme_z); pos(extreme_z(gg),3)=header.dim(3) ; end
        
        %WITHOUT REMOVING DUPLICATES:
        TRKS_OUT.sstr(ii).matrix(:,1:3)=tracts(ii).matrix(:,1:3);
        
        %THE LINE BELOW IS REPLACED WITH THREE CONDITIONS BASED ON THE FLIPPING
        %OF THE VALUES (AND INDEXING??) Edited 10_24_2017 by rdp20 (easy fix,
        %maybe a better solution should be implemented at a later stage)
        %TRKS_OUT.sstr(ii).vox_coord(:,1:3)=pos(:,1:3);
        if flag_x < 0 %Change by reversing all if vol_data differs from tract!
            %coords(:,ix) = header.dim(ix)*header.voxel_size(ix) - coords(:,ix);
            TRKS_OUT.sstr(ii).vox_coord(:,1)=pos(:,1)-1;
        else
            TRKS_OUT.sstr(ii).vox_coord(:,1)=pos(:,1);
        end
        if flag_y < 0
            TRKS_OUT.sstr(ii).vox_coord(:,2)=pos(:,2)-1;
        else
            TRKS_OUT.sstr(ii).vox_coord(:,2)=pos(:,2);
        end
        if flag_z < 0
            TRKS_OUT.sstr(ii).vox_coord(:,3)=pos(:,3)-1;
        else
            TRKS_OUT.sstr(ii).vox_coord(:,3)=pos(:,3);
        end
        
        
        %REMOVING DUPLICATES CODE WAS REMOVED AND REPLACED WITH:
        %~~~~> TRKS_OUT.unique_voxels and TRKS_OUT.num_uvox
        posnew_idx=1+posnew_idx;
        TRKS_OUT.sstr(ii).nPoints=size(TRKS_OUT.sstr(ii).matrix,1);
    end
else
    for jjj=1:size(tracts,2); TRKS_OUT.sstr(jjj).matrix=tracts(jjj).matrix; TRKS_OUT.sstr(jjj).nPoints=size(tracts(jjj).matrix,1); end
    warning('simple_read set as identifier, doing a fast simple read');
end


if ~strcmp(identifier,'simple_read')
    %Get the volume of non-overlapping XYZ vox_coord values
    all_vox=TRKS_OUT.sstr(1).vox_coord ;        %initializing vox_coord
    for ii=2:size(TRKS_OUT.sstr,2)
        all_vox=vertcat(all_vox,TRKS_OUT.sstr(ii).vox_coord);
    end
    %s_all_vox=sort(all_vox); %sort if bad! I believe it doesn't freeze the Y
    %and Z columns so no good to do this!
    TRKS_OUT.unique_voxels=unique(all_vox,'rows');
    TRKS_OUT.num_uvox=size(TRKS_OUT.unique_voxels,1);
    
    
    %ADDING ALL_SSTRLEN and MAXLEN:
    len=0;
    if size(TRKS_OUT.sstr,2) < 5000
        for ii=1:size(TRKS_OUT.sstr,2)
            cur_len=0;
            for jj=1:(size(TRKS_OUT.sstr(ii).matrix,1)-1)
                cur_len=cur_len+pdist2(TRKS_OUT.sstr(ii).matrix(jj,:),TRKS_OUT.sstr(ii).matrix(jj+1,:));
            end
            sstr_len(ii)=cur_len;
            if len < cur_len
                len=cur_len;
            end
        end
        TRKS_OUT.maxsstrlen=len;
        TRKS_OUT.all_sstrlen=sstr_len';
    else
        warning('Not calculating streamlines distances as there are >1000 streamlines and this could take a long time!');
    end
end
if ~isfield(TRKS_OUT,'maxsstrlen')
    TRKS_OUT.maxsstrlen=[];
    TRKS_OUT.all_sstrlen=[];
end





%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%




%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%LOCAL FUNCTION%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function header = get_header(fid)

header.id_string                 = fread(fid, 6, '*char')';
header.dim                       = fread(fid, 3, 'short')';
header.voxel_size                = fread(fid, 3, 'float')';
header.origin                    = fread(fid, 3, 'float')';
header.n_scalars                 = fread(fid, 1, 'short')';
header.scalar_name               = fread(fid, [20,10], '*char')';
header.n_properties              = fread(fid, 1, 'short')';
header.property_name             = fread(fid, [20,10], '*char')';
header.vox_to_ras                = fread(fid, [4,4], 'float')';
header.reserved                  = fread(fid, 444, '*char');
header.voxel_order               = fread(fid, 4, '*char')';
header.pad2                      = fread(fid, 4, '*char')';
header.image_orientation_patient = fread(fid, 6, 'float')';
header.pad1                      = fread(fid, 2, '*char')';
header.invert_x                  = fread(fid, 1, 'uchar');
header.invert_y                  = fread(fid, 1, 'uchar');
header.invert_z                  = fread(fid, 1, 'uchar');
header.swap_xy                   = fread(fid, 1, 'uchar');
header.swap_yz                   = fread(fid, 1, 'uchar');
header.swap_zx                   = fread(fid, 1, 'uchar');
header.n_count                   = fread(fid, 1, 'int')';
header.version                   = fread(fid, 1, 'int')';
header.hdr_size                  = fread(fid, 1, 'int')';



