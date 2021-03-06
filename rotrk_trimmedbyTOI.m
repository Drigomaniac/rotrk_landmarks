function [ TRKS_OUT ] = rotrk_trimmedbyROI(TRKS_IN, ROIS_IN, WHAT_TOI, ID)
%function [ TRKS_OUT ] = rotrk_trimmedbyROI(TRKS_IN, ROIS_IN, WHAT_TOI, ID)
%Goal: To trimmed TRKS_IN streamlines based on the `WHAT_TOI` tract of
%interest, using `ROI_IN` as the necessary parameters to be used. 
%Currently,
%   ROIS_IN should be:
%       for the Fornix: { 'dwi_Hippocampus' 'dwi_Thalamus' }
%       for the Hippocampal cinglum: { 'dwi_Hippocampus' 'dwi_PosteriorCingululate' }
%       for the Cinglum: { 'dwi_PosteriorCingululate' 'dwi_RostralAntCingululate' }
%       for ... <To implement> 
%Created by Rodrigo Perea


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%DEALING WITH INPUTS:
for tohide=1:1
    if nargin < 3
        error('no enough arguments. Plese re-run! ')
    end
    
    if nargin < 4
        ID='';
    end
    
    %Dealing with ROI_IN:
    for jj=1:numel(ROIS_IN)
        if ischar(ROIS_IN{jj})
            %roi_in=rotrk_ROIxyz(ROI_IN,WHAT_TOI,ROI_ORIENTATION);
            roi_in{jj}=rotrk_ROIxyz(ROIS_IN{jj}); %FIXED ISSUE, NOT LONGER NEEDED A 2nd ARGUMENT--> WHAT_TOI);
        else
            display('Not impoemented yet (easy fix!)...')
            error([ 'In: ' mfilename ' ROI_IN has only been implemented to use char types. Please implement otherwise']);
        end
    end
    
    
    %Dealing with TRKS_IN type:
    if isstruct(TRKS_IN)
        trks_in = TRKS_IN;
    else
        if ischar(TRKS_IN)
            trks_in=rotrk_read(TRKS_IN,ID,ROIS_IN{end},WHAT_TOI);
        else
            display('Not implemented yet (easy fix!)...')
            error([ 'In: ' mfilename ' TRKS_IN has only been implemented to use struct types. Please implement otherwise']);
        end
    end
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%




%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%IMPLEMETANTION STARTS HERE
%Preparing values
for jj=1:numel(ROIS_IN)
    %Trk_coord limits (not ideal for flagging as they dont exactly fit!)
    roi_lim{jj} = [ min(roi_in{jj}.approx_trk_coord(:,1)) max(roi_in{jj}.approx_trk_coord(:,1))  ...
        min(roi_in{jj}.approx_trk_coord(:,2)) max(roi_in{jj}.approx_trk_coord(:,2)) ...
        min(roi_in{jj}.approx_trk_coord(:,3)) max(roi_in{jj}.approx_trk_coord(:,3)) ] ;
    
    roi_mean{jj} = [  mean(roi_in{jj}.approx_trk_coord(:,1))  mean(roi_in{jj}.approx_trk_coord(:,2)) mean(roi_in{jj}.approx_trk_coord(:,3)) ] ;
    %Vox_coord limits:
    roi_vlim{jj} = [ min(roi_in{jj}.vox_coord(:,1)) max(roi_in{jj}.vox_coord(:,1))  ...
        min(roi_in{jj}.vox_coord(:,2)) max(roi_in{jj}.vox_coord(:,2)) ...
        min(roi_in{jj}.vox_coord(:,3)) max(roi_in{jj}.vox_coord(:,3)) ] ;
    
    roi_vmidpoint{jj} = [ (roi_vlim{jj}(2)+roi_vlim{jj}(1))/2 (roi_vlim{jj}(4)+roi_vlim{jj}(3))/2 (roi_vlim{jj}(6)+roi_vlim{jj}(5))/2] ;
    
end

%


%Dealing with specific TOIs
switch WHAT_TOI
    case {'fx_lh','fx_rh'}
        for tohide=1:1
            display('Trimming trks based on the hippocampus/thalamus (for the fornix bundle)');
            %FLIP VALUES TO START LEFT/RIGHT MOST ventral-anterior point of the HIPPOCAMPUS:
            if strcmp(WHAT_TOI,'fx_lh')
                flipped_trks_in = rotrk_flip(trks_in,[roi_vlim{1}(1) roi_vlim{1}(4) roi_vlim{1}(5)],true); %true denotes using vox_coord instead of trk coord!
            else
                flipped_trks_in = rotrk_flip(trks_in,[roi_vlim{1}(2) roi_vlim{1}(4) roi_vlim{1}(5)],true);
            end
            
            
            %CRITERIA FOR TRIMMING THE VALUES
            %(STARTING NEAR THE HIPPOCAMPUS):
            %   0) Remove strlines that start
            %      above the HIPPOCAMPUS max.
            %      z-value (below 1 voxel)
            %   1) Trim sstrlines below the
            %      midpoint of zy-HIPPOCAMPUS axis
            %      (tolerance of 2 voxel y-posteriorly)
            %   hippocampus (posterior - 2 voxels)
            %   2) Trim strlines based on the THALAMUS
            %      anterior-axis (tol. 2 voxels)
            %   3) Some tracts are AC projections, to avoid
            %      this, remove strlines that max-z values
            %      is below the midpoint z-axis of the THALAMUS
            
            %   All other values:
            for tohide_INIT_trkout=1:1
                temp_trks_out.sstr=flipped_trks_in.sstr;
                temp_trks_out.header=flipped_trks_in.header;
                trks_out.header=flipped_trks_in.header;
                trks_out.header.specific_name=[ 'trimmed_' flipped_trks_in.header.specific_name ] ;
                trks_out.id=flipped_trks_in.id;
                trks_out.sstr = [];
                if isfield(trks_out,'trk_name' ) ; trks_out.trk_name=[ 'trimmed_' flipped_trks_in.trk_name ]; end
            end
            
            %Criteria 0) Remove everything starting above the z-midpoint
            for itrk=1:numel(temp_trks_out.sstr)
                if temp_trks_out.sstr(itrk).vox_coord(1,3) > roi_vlim{1}(6)-1
                    temp_trks_out.sstr(itrk).matrix= [] ;
                    temp_trks_out.sstr(itrk).vox_coord = [] ;
                end
            end
            todebug=1;
            
            %Criteria 1 and 2)
            for itrk=1:numel(temp_trks_out.sstr)
                trim_first = false ;
                trim_second = false;
                if ~isempty(temp_trks_out.sstr(itrk).vox_coord)
                    %Criteria 1) Remove coords. above z-midpoint of hippo
                    %and anterior to y-midpoint
                    for ixyz=1:size(temp_trks_out.sstr(itrk).matrix,1)
                        if trks_in.header.invert_y == 1 % Verifies orientation of y-axis for comparison
                            if temp_trks_out.sstr(itrk).vox_coord(ixyz,3) > roi_vmidpoint{1}(3) && temp_trks_out.sstr(itrk).vox_coord(ixyz,2) < roi_vmidpoint{1}(2) + 2 % two voxels of tolerance
                                temp_trks_out.sstr(itrk).matrix(1:ixyz,:) = [] ;
                                temp_trks_out.sstr(itrk).vox_coord(1:ixyz,:) = [] ;
                                trim_first = true;
                                break
                            end
                        else
                            if temp_trks_out.sstr(itrk).vox_coord(ixyz,3) > roi_vmidpoint{1}(3) && temp_trks_out.sstr(itrk).vox_coord(ixyz,2) > roi_vmidpoint{1}(2) - 2 % two voxels of tolerance
                                temp_trks_out.sstr(itrk).matrix(1:ixyz,:) = [] ;
                                temp_trks_out.sstr(itrk).vox_coord(1:ixyz,:) = [] ;
                                trim_first = true;
                                break
                            end
                        end
                    end
                    todebug=1;
                    %Criteria 2) Remove coords. that go beyond anterior
                    %(y-axis) of thalamus
                    for ixyz=1:size(temp_trks_out.sstr(itrk).matrix,1)
                        if trks_in.header.invert_y == 1 % Verifies orientation of y-axis for comparison
                            if temp_trks_out.sstr(itrk).vox_coord(ixyz,2) > roi_vlim{2}(4) - 2  %tolerance of y-axis
                                temp_trks_out.sstr(itrk).matrix(ixyz:end,:) = [] ;
                                temp_trks_out.sstr(itrk).vox_coord(ixyz:end,:) = [] ;
                                trim_second = true;
                                break
                            end
                        else
                            if temp_trks_out.sstr(itrk).vox_coord(ixyz,2) < roi_vlim{2}(3) + 2  %tolerance of y-axis
                                temp_trks_out.sstr(itrk).matrix(ixyz:end,:) = [] ;
                                temp_trks_out.sstr(itrk).vox_coord(ixyz:end,:) = [] ;
                                trim_second = true;
                                break
                            end
                        end
                    end
                    %If first or second trim don't happened, then remove
                    %streamline. 2 conditions are always necessary!
                    if trim_second == false || trim_first == false
                        temp_trks_out.sstr(itrk).matrix = [];
                        temp_trks_out.sstr(itrk).vox_coord = [];
                    end
                end
            end
            todebug=1;
            
            %Criteria 3) - Remove streamlines below the z-midpoint of the
            %thalamus
            flag_criteria3=0;
            for itrk=1:numel(temp_trks_out.sstr)
                if ~isempty(temp_trks_out.sstr(itrk).vox_coord)
                    %Y-axis criteria:
                    [maxZval maxZidx ] = max(temp_trks_out.sstr(itrk).vox_coord(:,3));
                    if temp_trks_out.sstr(itrk).vox_coord(maxZidx,3) < roi_vmidpoint{2}(3)
                        temp_trks_out2.sstr(itrk).matrix = [];
                        temp_trks_out2.sstr(itrk).vox_coord = [];
                        flag_criteria3=1+flag_criteria3;
                    end
                end
            end
            
            
            
%             %REMOVE EMPTY *.matrix and *.sstr columns (where trimming did
%             %not occur:
            trk_count=1;
            %trks_out.sstr.vox_coord = [];
            for itrk=1:numel(temp_trks_out.sstr)
                if ~isempty(temp_trks_out.sstr(itrk).matrix)
                    trks_out.sstr(trk_count).matrix=temp_trks_out.sstr(itrk).matrix;
                    trks_out.sstr(trk_count).vox_coord=temp_trks_out.sstr(itrk).vox_coord;
                    trk_count=trk_count+1;
                end
            end
        end
            
    case {'postcing_lh', 'postcing_rh'}
        for tohide=1:1
            display('Trimming trks based on the hippocampal cingulum modification');
            %Flip trks to start at the most anterior regions:
            tmp_val=[];
            tmpmaxidx = [];
            %Now for the lowest part of hippo
            flipped_trks_in = rotrk_flip(trks_in,[roi_vlim{1}(2) roi_vlim{1}(4) roi_vlim{1}(5)  ],true);
            
            %CRITERIA FOR TRIMMING THE VALUES:
            %   1) Remove everything below the z-axis midpoint of
            %   hippocampus once it reaches it
            %   2) Remove everything above the yz-axis midpoint of the
            %   posterior cingulate
            %   ** Then,
            %   3) a for loop will check and replace those
            %   streamlines that arent posterior to the hippocampus
            %   (y-lowest value) and in between lower z-postcingut and
            %   upper z-hippocampus
            
            %   All other values:
            for tohide_INIT_trkout=1:1
                temp_trks_out.sstr=flipped_trks_in.sstr;
                trks_out.header=flipped_trks_in.header;
                trks_out.header.specific_name=[ 'trimmed_' flipped_trks_in.header.specific_name ] ;
                trks_out.id=flipped_trks_in.id;
                trks_out.sstr = [];
                trks_out.trk_name=[ 'trimmed_' flipped_trks_in.trk_name ];
            end
            for itrk=1:numel(temp_trks_out.sstr)
                trim_first = false ;
                trim_second = false;
                %Criteria 1) - same as criteria 1 for fx
                for ixyz=1:size(temp_trks_out.sstr(itrk).matrix,1)
                    if trks_in.header.invert_y == 1 % Verifies orientation of y-axis for comparison
                        if temp_trks_out.sstr(itrk).vox_coord(ixyz,3) > roi_vmidpoint{1}(3) && temp_trks_out.sstr(itrk).vox_coord(ixyz,2) < roi_vmidpoint{1}(2) + 2 % two voxels of tolerance
                            temp_trks_out.sstr(itrk).matrix(1:ixyz,:) = [] ;
                            temp_trks_out.sstr(itrk).vox_coord(1:ixyz,:) = [] ;
                            trim_first = true;
                            break
                        end
                    else
                        if temp_trks_out.sstr(itrk).vox_coord(ixyz,3) > roi_vmidpoint{1}(3) && temp_trks_out.sstr(itrk).vox_coord(ixyz,2) > roi_vmidpoint{1}(2) - 2 % two voxels of tolerance
                            temp_trks_out.sstr(itrk).matrix(1:ixyz,:) = [] ;
                            temp_trks_out.sstr(itrk).vox_coord(1:ixyz,:) = [] ;
                            trim_first = true;
                            break
                        end
                    end
                end
                %Criteria 2)
                for ixyz=1:size(temp_trks_out.sstr(itrk).matrix,1)
                    if trks_in.header.invert_y == 1 % Verifies orientation of y-axis for comparison
                        if temp_trks_out.sstr(itrk).vox_coord(ixyz,2) > roi_vmidpoint{2}(2) && temp_trks_out.sstr(itrk).vox_coord(ixyz,3) > roi_vlim{2}(5) - 3 %tolerance of z-axis
                            temp_trks_out.sstr(itrk).matrix(ixyz:end,:) = [] ;
                            temp_trks_out.sstr(itrk).vox_coord(ixyz:end,:) = [] ;
                            trim_second = true;
                            break
                        end
                    else
                        if temp_trks_out.sstr(itrk).vox_coord(ixyz,2) < roi_vmidpoint{2}(2) && temp_trks_out.sstr(itrk).vox_coord(ixyz,3) > roi_vlim{2}(5) - 3 %tolerance of z-axis
                            temp_trks_out.sstr(itrk).matrix(ixyz:end,:) = [] ;
                            temp_trks_out.sstr(itrk).vox_coord(ixyz:end,:) = [] ;
                            trim_second = true;
                            break
                        end
                    end
                end
                %If first or second trim don't happened, then remove
                %streamline
                if trim_second == false || trim_first == false
                    temp_trks_out.sstr(itrk).matrix = [];
                    temp_trks_out.sstr(itrk).vox_coord = [];
                end
            end
            
            %Criteria 3) - This will get rid of CST tracts or anything that
            %doesnt go posterior to the hipopcampus (check criteria
            %parameter above).
            nothing=1;
            
            for itrk=1:numel(temp_trks_out.sstr)
                if ~isempty(temp_trks_out.sstr(itrk).vox_coord)
                    %X-axis criteria:
                    if strcmp(WHAT_TOI,'postcing_lh') %Check if its way beyond  the x-axis (left-right)
                        if trks_in.header.invert_x == 1 % Verifies orientation of x-axis for comparison
                            [Xval Xidx ] = min(temp_trks_out.sstr(itrk).vox_coord(:,1));
                            if temp_trks_out.sstr(itrk).vox_coord(Xidx,1) < roi_vmidpoint{1}(1) - 5 %tolerance of 5
                                temp_trks_out.sstr(itrk).matrix = [];
                                temp_trks_out.sstr(itrk).vox_coord = [];
                                continue
                            end
                        else
                            [Xval Xidx ] = max(temp_trks_out.sstr(itrk).vox_coord(:,1));
                            if temp_trks_out.sstr(itrk).vox_coord(Xidx,1) > roi_vmidpoint{1}(1) + 5 %tolerance of 5
                                temp_trks_out.sstr(itrk).matrix = [];
                                temp_trks_out.sstr(itrk).vox_coord = [];
                                continue
                            end
                        end
                    else
                        if trks_in.header.invert_x == 1 % Verifies orientation of x-axis for comparison
                            [Xval Xidx ] = max(temp_trks_out.sstr(itrk).vox_coord(:,1));
                            if temp_trks_out.sstr(itrk).vox_coord(Xidx,1) > roi_vmidpoint{1}(1) + 5 %tolerance of 5
                                temp_trks_out.sstr(itrk).matrix = [];
                                temp_trks_out.sstr(itrk).vox_coord = [];
                                continue
                            end
                        else
                            [Xval Xidx ] = min(temp_trks_out.sstr(itrk).vox_coord(:,1));
                            if temp_trks_out.sstr(itrk).vox_coord(Xidx,1) < roi_vmidpoint{1}(1) - 5 %tolerance of 5
                                temp_trks_out.sstr(itrk).matrix = [];
                                temp_trks_out.sstr(itrk).vox_coord = [];
                                continue
                            end
                        end
                    end
                    
                    %Y-axis criteria:
                    if trks_in.header.invert_y == 1
                        [minYval minYidx ] = min(temp_trks_out.sstr(itrk).vox_coord(:,2));
                        if temp_trks_out.sstr(itrk).vox_coord(minYidx,2) > roi_vlim{1}(3)
                            temp_trks_out.sstr(itrk).matrix = [];
                            temp_trks_out.sstr(itrk).vox_coord = [];
                        end
                    else
                        [maxYval maxYidx ] = max(temp_trks_out.sstr(itrk).vox_coord(:,2));
                        if temp_trks_out.sstr(itrk).vox_coord(maxYidx,2) < roi_vlim{1}(4)
                            temp_trks_out.sstr(itrk).matrix = [];
                            temp_trks_out.sstr(itrk).vox_coord = [];
                        end
                    end
                end
            end
            
            %REMOVE EMPTY *.matrix and *.sstr columns (where trimming did
            %not occur:
            trk_count=1;
            %trks_out.sstr.vox_coord = [];
            for itrk=1:numel(temp_trks_out.sstr)
                if ~isempty(temp_trks_out.sstr(itrk).matrix)
                    trks_out.sstr(trk_count).matrix=temp_trks_out.sstr(itrk).matrix;
                    trks_out.sstr(trk_count).vox_coord=temp_trks_out.sstr(itrk).vox_coord;
                    trk_count=trk_count+1;
                end
            end
            
        end
    case {'cingulum_lh', 'cingulum_rh'}
        for tohide=1:1
            display('Trimming trks based on the anterior cingulum modification');
            %Flip trks to start at the most anterior regions (or minimun y-axis):
            tmp_val=[];
            tmpmaxidx = [];
            flip_ystrline=0;
            for itrk=1:numel(trks_in.sstr)
                if trks_in.header.invert_y == 1
                    [ tmp_val, tmp_idx ] = min(trks_in.sstr(itrk).matrix(:,2));
                    if tmp_val < flip_ystrline
                        flip_ystrline=trks_in.sstr(itrk).matrix(tmp_idx,1:3);
                    end
                else
                    [ tmp_val, tmp_idx ] = max(trks_in.sstr(itrk).matrix(:,2));
                    if tmp_val > flip_ystrline
                        flip_ystrline=trks_in.sstr(itrk).matrix(tmp_idx,1:3);
                    end
                end
            end
            flipped_trks_in = rotrk_flip(trks_in,flip_ystrline,true);
            AA=1;
            
            
            %CRITERIA FOR TRIMMING THE VALUES:
            %   STARTING AT MOST POSTERIOR PART
            %   1) Remove everything posterior to the midpoint of posterior
            %   cingulate AND (that include at least the lowest z-axis in
            %   the posterior cingulate)
            %   2) Remove everything anterior to the midpoint of the anterior cingulate
            %   ** Then,
            %   3) (to do if needed)
            
            %   All other values:
            for tohide_INIT_trkout=1:1
                temp_trks_out.sstr=flipped_trks_in.sstr;
                
                trks_out.header=flipped_trks_in.header;
                trks_out.header.specific_name=[ 'trimmed_' flipped_trks_in.header.specific_name ] ;
                trks_out.id=flipped_trks_in.id;
                trks_out.sstr = [];
                trks_out.trk_name=[ 'trimmed_' flipped_trks_in.trk_name ];
            end
            for itrk=1:numel(temp_trks_out.sstr)
                trim_first = false ;
                trim_second = false;
                %Criteria 1)
                for ixyz=1:size(temp_trks_out.sstr(itrk).matrix,1)
                    if trks_in.header.invert_y == 1 % Verifies orientation of y-axis for comparison
                        if temp_trks_out.sstr(itrk).vox_coord(ixyz,2) > roi_vmidpoint{1}(2) && temp_trks_out.sstr(itrk).vox_coord(ixyz,3) > roi_vlim{1}(5)
                            temp_trks_out.sstr(itrk).matrix(1:ixyz,:) = [] ;
                            temp_trks_out.sstr(itrk).vox_coord(1:ixyz,:) = [] ;
                            trim_first = true;
                            break
                        end
                    else
                        if temp_trks_out.sstr(itrk).vox_coord(ixyz,2) < roi_vmidpoint{1}(2) && temp_trks_out.sstr(itrk).vox_coord(ixyz,3) > roi_vlim{1}(5)
                            temp_trks_out.sstr(itrk).matrix(1:ixyz,:) = [] ;
                            temp_trks_out.sstr(itrk).vox_coord(1:ixyz,:) = [] ;
                            trim_first = true;
                            break
                        end
                    end
                end
                %Criteria 2)
                for ixyz=1:size(temp_trks_out.sstr(itrk).matrix,1)
                    if trks_in.header.invert_y == 1 % Verifies orientation of y-axis for comparison
                        if temp_trks_out.sstr(itrk).vox_coord(ixyz,2) > roi_vmidpoint{2}(2) % Commented as no all fiber will reach the midpoint of z-axis --> && temp_trks_out.sstr(itrk).vox_coord(ixyz,3) < roi_vmidpoint{2}(3) % no tolerance of z-axis
                            temp_trks_out.sstr(itrk).matrix(ixyz:end,:) = [] ;
                            temp_trks_out.sstr(itrk).vox_coord(ixyz:end,:) = [] ;
                            trim_second = true;
                            break
                        end
                    else
                        if temp_trks_out.sstr(itrk).vox_coord(ixyz,2) < roi_vmidpoint{2}(2) % Commented as no all fiber will reach the midpoint of z-axis --> && temp_trks_out.sstr(itrk).vox_coord(ixyz,3) < roi_vmidpoint{2}(3) % no tolerance of z-axis
                            temp_trks_out.sstr(itrk).matrix(ixyz:end,:) = [] ;
                            temp_trks_out.sstr(itrk).vox_coord(ixyz:end,:) = [] ;
                            trim_second = true;
                            break
                        end
                    end
                end
                %If first or second trim don't happened, then remove
                %streamline
                if trim_second == false || trim_first == false
                    temp_trks_out.sstr(itrk).matrix = [];
                    temp_trks_out.sstr(itrk).vox_coord = [];
                end
            end
            for tohide_criteria3=1:1
                %             %Criteria 3) - Under development if needed.
                %             for itrk=1:numel(temp_trks_out.sstr)
                %                 if ~isempty(temp_trks_out.sstr(itrk).vox_coord)
                %                     %X-axis criteria:
                %                     if strcmp(WHAT_TOI,'cingulum_lh') %Check if its way beyond
                %                         [Xval Xidx ] = min(temp_trks_out.sstr(itrk).vox_coord(:,1));
                %                         if temp_trks_out.sstr(itrk).vox_coord(Xidx,1) < roi_vmidpoint{1}(1) - 5 %tolerance of 5
                %                             temp_trks_out.sstr(itrk).matrix = [];
                %                             temp_trks_out.sstr(itrk).vox_coord = [];
                %                             continue
                %                         end
                %                     else
                %                         [Xval Xidx ] = max(temp_trks_out.sstr(itrk).vox_coord(:,1));
                %                         if temp_trks_out.sstr(itrk).vox_coord(Xidx,1) > roi_vmidpoint{1}(1) + 5 %tolerance of 5
                %                             temp_trks_out.sstr(itrk).matrix = [];
                %                             temp_trks_out.sstr(itrk).vox_coord = [];
                %                             continue
                %                         end
                %                     end
                %
                %                     %Y-axis criteria:
                %                     [minYval minYidx ] = min(temp_trks_out.sstr(itrk).vox_coord(:,2));
                %                     if temp_trks_out.sstr(itrk).vox_coord(minYidx,2) > roi_vlim{1}(3)
                %                         temp_trks_out.sstr(itrk).matrix = [];
                %                         temp_trks_out.sstr(itrk).vox_coord = [];
                %                     end
                %                 end
                %             end
                %
            end
            %REMOVE EMPTY *.matrix and *.sstr columns (where trimming did
            %not occur:
            trk_count=1;
            %trks_out.sstr.vox_coord = [];
            for itrk=1:numel(temp_trks_out.sstr)
                if ~isempty(temp_trks_out.sstr(itrk).matrix)
                    trks_out.sstr(trk_count).matrix=temp_trks_out.sstr(itrk).matrix;
                    trks_out.sstr(trk_count).vox_coord=temp_trks_out.sstr(itrk).vox_coord;
                    trk_count=trk_count+1;
                end
            end
        end
        
    case {'atr_rh', 'atr_lh'}
        for tohide=1:1
            display('Trimming trks based on the hippocampus/thalamus (for the fornix bundle)');
            
            %FLIP VALUES TO START NEAR THE MIDPOINT OF Thalamus:
            flipped_trks_in = rotrk_flip(trks_in,roi_vmidpoint{1});
            
            %CRITERIA FOR TRIMMING THE VALUES (STARTING NEAR THE HIPPOCAMPUS):
            %   1) Remove everything that is not within the z-axis limits
            %   of the thalamus AND midpoint of the y-axis thalamus
            %   2) Remove everything anteior to the midpoint-yaxis of the
            %   anterior cingulate
            %   ** Then,
            %   3) Remove those strlines that cross to the other hemisphere
            %   (and are combined with the corpus callosum)
            
            %   All other values:
            for tohide_INIT_trkout=1:1
                temp_trks_out.sstr=flipped_trks_in.sstr;
                
                trks_out.header=flipped_trks_in.header;
                trks_out.header.specific_name=[ 'trimmed_' flipped_trks_in.header.specific_name ] ;
                trks_out.id=flipped_trks_in.id;
                trks_out.sstr = [];
                trks_out.trk_name=[ 'trimmed_' flipped_trks_in.trk_name ];
            end
            for itrk=1:numel(temp_trks_out.sstr)
                trim_first = false ;
                trim_second = false;
                %Criteria 1)
                for ixyz=1:size(temp_trks_out.sstr(itrk).matrix,1)
                    if temp_trks_out.sstr(itrk).vox_coord(ixyz,3) < roi_vlim{1}(6)  && temp_trks_out.sstr(itrk).vox_coord(ixyz,3) > roi_vlim{1}(5)
                        if trks_in.header.invert_y == 1 % Verifies orientation of y-axis for comparison
                            if temp_trks_out.sstr(itrk).vox_coord(ixyz,2) > roi_vmidpoint{1}(2)
                                temp_trks_out.sstr(itrk).matrix(1:ixyz,:) = [] ;
                                temp_trks_out.sstr(itrk).vox_coord(1:ixyz,:) = [] ;
                                trim_first = true;
                                break
                            end
                        else
                            if temp_trks_out.sstr(itrk).vox_coord(ixyz,2) < roi_vmidpoint{1}(2)
                                temp_trks_out.sstr(itrk).matrix(1:ixyz,:) = [] ;
                                temp_trks_out.sstr(itrk).vox_coord(1:ixyz,:) = [] ;
                                trim_first = true;
                                break
                            end
                        end
                    end
                end
                %Criteria 2)
                for ixyz=1:size(temp_trks_out.sstr(itrk).matrix,1)
                    if trks_in.header.invert_y == 1 % Verifies orientation of y-axis for comparison
                        if temp_trks_out.sstr(itrk).vox_coord(ixyz,2) > roi_vmidpoint{2}(2) - 2  %tolerance of y-axis (a little shorter to avoid contamination w/ corpus callosum
                            temp_trks_out.sstr(itrk).matrix(ixyz:end,:) = [] ;
                            temp_trks_out.sstr(itrk).vox_coord(ixyz:end,:) = [] ;
                            trim_second = true;
                            break
                        end
                    else
                        if temp_trks_out.sstr(itrk).vox_coord(ixyz,2) < roi_vmidpoint{2}(2) + 2  %tolerance of y-axis (a little shorter to avoid contamination w/ corpus callosum
                            temp_trks_out.sstr(itrk).matrix(ixyz:end,:) = [] ;
                            temp_trks_out.sstr(itrk).vox_coord(ixyz:end,:) = [] ;
                            trim_second = true;
                            break
                        end
                    end
                end
                %If first or second trim don't happened, then remove
                %streamline
                if trim_second == false || trim_first == false
                    temp_trks_out.sstr(itrk).matrix = [];
                    temp_trks_out.sstr(itrk).vox_coord = [];
                end
            end
            
            %Criteria 3) - Removing those streamlines that cross the
            %midline section
            nothing=1;
            
            for itrk=1:numel(temp_trks_out.sstr)
                if ~isempty(temp_trks_out.sstr(itrk).vox_coord)
                    %X-axis criteria:
                    if strcmp(WHAT_TOI,'atr_lh') %Check if its on the other hemisphere
                        if trks_in.header.invert_x == 1 % Verifies orientation of x-axis for comparison
                            if temp_trks_out.sstr(itrk).vox_coord(end,1) > roi_vlim{2}(2)
                                temp_trks_out.sstr(itrk).matrix = [];
                                temp_trks_out.sstr(itrk).vox_coord = [];
                                continue
                            end
                        else
                            if temp_trks_out.sstr(itrk).vox_coord(end,1) < roi_vlim{2}(1)
                                temp_trks_out.sstr(itrk).matrix = [];
                                temp_trks_out.sstr(itrk).vox_coord = [];
                                continue
                            end
                        end
                    else
                        if trks_in.header.invert_x == 1 % Verifies orientation of x-axis for comparison
                            if temp_trks_out.sstr(itrk).vox_coord(end,1) < roi_vlim{2}(1)
                                temp_trks_out.sstr(itrk).matrix = [];
                                temp_trks_out.sstr(itrk).vox_coord = [];
                                continue
                            end
                        else
                            if temp_trks_out.sstr(itrk).vox_coord(end,1) > roi_vlim{2}(2)
                                temp_trks_out.sstr(itrk).matrix = [];
                                temp_trks_out.sstr(itrk).vox_coord = [];
                                continue
                            end
                        end
                    end
                end
            end
            
            %REMOVE EMPTY *.matrix and *.sstr columns (where trimming did
            %not occur:
            trk_count=1;
            %trks_out.sstr.vox_coord = [];
            for itrk=1:numel(temp_trks_out.sstr)
                if ~isempty(temp_trks_out.sstr(itrk).matrix)
                    trks_out.sstr(trk_count).matrix=temp_trks_out.sstr(itrk).matrix;
                    trks_out.sstr(trk_count).vox_coord=temp_trks_out.sstr(itrk).vox_coord;
                    trk_count=trk_count+1;
                end
            end
        end
        
    case {'isthmus'}
        for tohide=1:1
            display('Trimming trks based on the isthmus modification');
            %Flip trks to start at the lower most regions (or minimun z-axis):
            tmp_val=[];
            tmpmaxidx = [];
            flip_zstrline=600;
            for itrk=1:numel(trks_in.sstr)
                if trks_in.header.invert_y == 1
                    [ tmp_val, tmp_idx ] = min(trks_in.sstr(itrk).matrix(:,3));
                    if tmp_val < flip_zstrline
                        flip_zstrline=trks_in.sstr(itrk).matrix(tmp_idx,1:3);
                    end
                    
                end
            end
            flipped_trks_in = rotrk_flip(trks_in,flip_zstrline,true);
            AA=1;
            
            
            %CRITERIA FOR TRIMMING THE VALUES:
            %   STARTING AT MOST ANTERIOR PART (CLOSE TO HIPPOCAMPUS)
            %   1) Remove everything below the highest z-axis of the
            %   hippocampus (ROI1)
            
            %   2) Remove everything above the midpoint z-axis of the
            %   isthmus (ROI2)
            
            %   All other values:
            for tohide_INIT_trkout=1:1
                temp_trks_out.sstr=flipped_trks_in.sstr;
                
                trks_out.header=flipped_trks_in.header;
                trks_out.header.specific_name=[ 'trimmed_' flipped_trks_in.header.specific_name ] ;
                trks_out.id=flipped_trks_in.id;
                trks_out.sstr = [];
                trks_out.trk_name=[ 'trimmed_' flipped_trks_in.trk_name ];
            end
            for itrk=1:numel(temp_trks_out.sstr)
                trim_first = false ;
                trim_second = false;
                %Criteria 1)
                for ixyz=1:size(temp_trks_out.sstr(itrk).matrix,1)
                    if temp_trks_out.sstr(itrk).vox_coord(ixyz,3) > roi_vmidpoint{1}(3)  %+3 %% && temp_trks_out.sstr(itrk).vox_coord(ixyz,3) > roi_vlim{1}(5)
                        temp_trks_out.sstr(itrk).matrix(1:ixyz,:) = [] ;
                        temp_trks_out.sstr(itrk).vox_coord(1:ixyz,:) = [] ;
                        trim_first = true;
                        crit1_xyz=ixyz;
                        %TODEBUG disp(num2str(ixyz));
                        break
                    end
                end
                
                %Criteria 2)
                if trim_first ~= false
                    for ixyz=crit1_xyz:size(temp_trks_out.sstr(itrk).matrix,1)
                        if temp_trks_out.sstr(itrk).vox_coord(ixyz,3) > roi_vmidpoint{2}(3) % Commented as no all fiber will reach the midpoint of z-axis --> && temp_trks_out.sstr(itrk).vox_coord(ixyz,3) < roi_vmidpoint{2}(3) % no tolerance of z-axis
                            temp_trks_out.sstr(itrk).matrix(ixyz:end,:) = [] ;
                            temp_trks_out.sstr(itrk).vox_coord(ixyz:end,:) = [] ;
                            trim_second = true;
                            break
                        end
                        
                    end
                end
                %trim_second
                %If first or second trim don't happened, then remove
                %streamline
                if trim_second == false || trim_first == false
                    temp_trks_out.sstr(itrk).matrix = [];
                    temp_trks_out.sstr(itrk).vox_coord = [];
                end
                
                for tohide_criteria3=1:1
                    %             %Criteria 3) - Under development if needed.
                    %             for itrk=1:numel(temp_trks_out.sstr)
                    %                 if ~isempty(temp_trks_out.sstr(itrk).vox_coord)
                    %                     %X-axis criteria:
                    %                     if strcmp(WHAT_TOI,'cingulum_lh') %Check if its way beyond
                    %                         [Xval Xidx ] = min(temp_trks_out.sstr(itrk).vox_coord(:,1));
                    %                         if temp_trks_out.sstr(itrk).vox_coord(Xidx,1) < roi_vmidpoint{1}(1) - 5 %tolerance of 5
                    %                             temp_trks_out.sstr(itrk).matrix = [];
                    %                             temp_trks_out.sstr(itrk).vox_coord = [];
                    %                             continue
                    %                         end
                    %                     else
                    %                         [Xval Xidx ] = max(temp_trks_out.sstr(itrk).vox_coord(:,1));
                    %                         if temp_trks_out.sstr(itrk).vox_coord(Xidx,1) > roi_vmidpoint{1}(1) + 5 %tolerance of 5
                    %                             temp_trks_out.sstr(itrk).matrix = [];
                    %                             temp_trks_out.sstr(itrk).vox_coord = [];
                    %                             continue
                    %                         end
                    %                     end
                    %
                    %                     %Y-axis criteria:
                    %                     [minYval minYidx ] = min(temp_trks_out.sstr(itrk).vox_coord(:,2));
                    %                     if temp_trks_out.sstr(itrk).vox_coord(minYidx,2) > roi_vlim{1}(3)
                    %                         temp_trks_out.sstr(itrk).matrix = [];
                    %                         temp_trks_out.sstr(itrk).vox_coord = [];
                    %                     end
                    %                 end
                    %             end
                    %
                end
                %REMOVE EMPTY *.matrix and *.sstr columns (where trimming did
                %not occur:
                trk_count=1;
            end
            %trks_out.sstr.vox_coord = [];
            if  isfield(temp_trks_out,'sstr') == 0
                [~, bb, cc ] = fileparts(TRKS_IN);
                warning([ bb cc ' cannnot be trimmed']);
                TRKS_OUT=false;
                return
                
            else
                for itrk=1:numel(temp_trks_out.sstr)
                    if ~isempty(temp_trks_out.sstr(itrk).matrix)
                        trks_out.sstr(trk_count).matrix=temp_trks_out.sstr(itrk).matrix;
                        trks_out.sstr(trk_count).vox_coord=temp_trks_out.sstr(itrk).vox_coord;
                        trk_count=trk_count+1;
                    end
                end
            end
        end
        
    otherwise
        error(['WHAT_TOI argument: ' WHAT_TOI ' in ' mfilename ' is not implemented. Either check input or implement!' ]);
        
end


%OTHER IMPLEMENTATION EQUAL FOR EVERY TOI:
for itrk=1:numel(trks_out.sstr)
    if isempty(trks_out.sstr(itrk).vox_coord)
        if itrk ~=1
            trks_out.sstr(itrk).vox_coord=trks_out.sstr(itrk-1).vox_coord;
            trks_out.sstr(itrk).matrix=trks_out.sstr(itrk-1).matrix;
        else
            trks_out.sstr(itrk).vox_coord=trks_out.sstr(end).vox_coord;
            trks_out.sstr(itrk).matrix=trks_out.sstr(end).matrix;
        end
    end
end


%Input the nPoints information:
for itrk=1:numel(trks_out.sstr)
    trks_out.sstr(itrk).nPoints=size(trks_out.sstr(itrk).matrix,1);
end

%Header n_count <update> information
trks_out.header.n_count = numel(trks_out.sstr);

if isempty(trks_out.sstr)
    
    %Moving TRKS_OUT to exit...
    TRKS_OUT=trks_out;
    warning(['Cannot do ' WHAT_TOI 'trimming!']);
else
    %Get Unique voxels information
    all_vox=trks_out.sstr(1).vox_coord ;        %initializing vox_coord
    for ii=2:size(trks_out.sstr,2)
        all_vox=vertcat(all_vox,trks_out.sstr(ii).vox_coord);
    end
    %s_all_vox=sort(all_vox); %sort if bad! I believe it doesn't freeze the Y
    %and Z columns so no good to do this!
    trks_out.unique_voxels=unique(all_vox,'rows');
    trks_out.num_uvox=size(trks_out.unique_voxels,1);
    
    %Moving TRKS_OUT to exit...
    TRKS_OUT=trks_out;
    
    
    
    %ADDING MAXLEN:
    len=0;
    for ii=1:size(TRKS_OUT.sstr,2)
        cur_len=0;
        for jj=1:(size(TRKS_OUT.sstr(ii).matrix,1)-1)
            cur_len=cur_len+pdist2(TRKS_OUT.sstr(ii).matrix(jj,:),TRKS_OUT.sstr(ii).matrix(jj+1,:));
        end
        if len < cur_len
            len=cur_len;
        end
    end
    TRKS_OUT.maxsstrlen=len;
    
end

