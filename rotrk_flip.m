function [TRKS_OUT, pt_start] = rotrk_flip(TRKS_IN,pt_start,vox_coord,opt)
%function [TRKS_OUT, pt_start] = rotrk_flip(TRKS_IN,pt_start,vox_coord,opt)
%TRK_FLIP - Flip the ordering of tracks
%When TrackVis stores .trk files, the ordering of the points are not always
%optimal (e.g. the corpus callosum will have some tracks starting on the left
%and some on the right). TRK_FLIP solves this problem by reordering streamlines
%so that the terminal points nearest to point 'pt_start' will be the starting
%points.
%
% Modified by Rodrigo Perea with along-tracts code (original creator John Colby)
% There are some issues with the trk coordinates so I highly recommend
% using the opt option to (true) so trk_flip occurs in the vox_coord
% instead of the .metric coordinate! 
% Inputs:
%    TRKS_IN  - Header and tracts information from .trk file [struc]
%    pt_start  - XYZ voxel coordinates to which streamline start points will be
%                matched. If not given, will determine interactively. [1 x 3]
% Outputs:
%    TRKS_OUT - Output tracks (matrix or struc form, depending on input). Same
%                 vertices as tracts_in, but the ordering of some tracks will
%                 now be reversed.
%    pt_start   - Useful to collect the interactively found pt_starts.
%
%    *Added support for vox_coord! 

%%%%%%%%SPLITTING THTE TRKS FORM INTO TRACTS AND HEADER
tracts_in=TRKS_IN.sstr;
header=TRKS_IN.header;
TRKS_OUT=TRKS_IN; %re-assigned at the end...
%~~~


if nargin < 3
    voxcoord=false;
else
    voxcoord=true;
end

if nargin < 4
    opt='';
end
    


tracts_out = tracts_in;

% Fast algebra if streamlines are all the same length
if isnumeric(tracts_in)
%     if any(isnan(tracts_in(:)))
%         error('If you are going to deal with streamlines padded with NaNs (i.e. different lengths), they should be flipped FIRST.')
%     end
%     % Determine if the first or last track point is closer to 'pt_start'
%     if length(size(tracts_in))==2  % Only 1 streamliine
%         point_1   = sqrt(sum(bsxfun(@minus, tracts_in(1,:,:), pt_start).^2, 2));
%         point_end = sqrt(sum(bsxfun(@minus, tracts_in(end,:,:), pt_start).^2, 2));
%     else
%         point_1   = sqrt(sum(squeeze(bsxfun(@minus, tracts_in(1,:,:), pt_start))'.^2, 2));
%         point_end = sqrt(sum(squeeze(bsxfun(@minus, tracts_in(end,:,:), pt_start))'.^2, 2));
%     end
%     
%     % Flip the tracks whose first points are not closest to 'pt_start'
%     ind                 = point_end < point_1;
%     tracts_out(:,:,ind) = tracts_in(fliplr(1:end),:,ind);
    warning('THERE IS NO rotrk_flip support for *.sstr.vox_coord! only sstr.matrx')
% Otherwise, loop through one by one
else
    if any(isnan(cat(1,tracts_in.matrix)))
        error('If you are going to deal with streamlines padded with NaNs (i.e. different lengths), they should be flipped FIRST.')
    end
    if size(tracts_in(1).matrix, 2) > 3
       error('Streamlines should be flipped before scalars are attached.') 
    end
    for iTrk=1:length(tracts_in)
        if voxcoord==true
            % Determine if the first or last track point is closer to 'pt_start'
            point_1   = sqrt(sum((tracts_in(iTrk).vox_coord(1,1:3) - pt_start).^2));
            point_end = sqrt(sum((tracts_in(iTrk).vox_coord(end,1:3) - pt_start).^2));
            %Issues with single vs. double types so using the functions above...
            %point_1=pdist2(tracts_in(iTrk).vox_coord(1,1:3),pt_start);
            %point_end=pdist2(tracts_in(iTrk).vox_coord(end,1:3),pt_start);
            
        else
            % Determine if the first or last track point is closer to 'pt_start'
            point_1   = sqrt(sum((tracts_in(iTrk).matrix(1,1:3) - pt_start).^2));
            point_end = sqrt(sum((tracts_in(iTrk).matrix(end,1:3) - pt_start).^2));
            
        end
        % Flip the tracks whose first points are not closest to 'pt_start'
        if strcmp(opt,'away')  %Moving initial points away from the point of interest
            if point_end > point_1;
                tracts_out(iTrk).matrix   = flipud(tracts_in(iTrk).matrix);
                %Added support for vox_coord struct type!
                if isfield(tracts_out,'vox_coord')
                    tracts_out(iTrk).vox_coord   = flipud(tracts_in(iTrk).vox_coord);
                end
            end
        else
            if point_end < point_1;
                tracts_out(iTrk).matrix   = flipud(tracts_in(iTrk).matrix);
                %Added support for vox_coord struct type!
                if isfield(tracts_out,'vox_coord')
                    tracts_out(iTrk).vox_coord   = flipud(tracts_in(iTrk).vox_coord);
                end
            end
        end
    end
end


%%
TRKS_OUT.sstr=tracts_out;



