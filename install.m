function install()
% INSTALL Sets up PowerBiMIP.
% Just adds the necessary folders to your path. Simple.

    disp(' ');
    disp('>> PowerBiMIP Installer started.');
    disp('>> Let''s see where we are...');

    % 1. Get the current root
    root = fileparts(mfilename('fullpath'));
    fprintf('   Root detected: %s\n', root);

    % 2. Folders to add
    targets = {'config', 'examples', 'src'};
    
    disp('>> Feeding folders to MATLAB...');
    
    found_count = 0;
    for k = 1:length(targets)
        item = targets{k};
        targetPath = fullfile(root, item);
        
        if isfolder(targetPath)
            % Add folder and subfolders
            addpath(genpath(targetPath));
            fprintf('   [+] %s ... added.\n', item);
            found_count = found_count + 1;
        else
            fprintf('   [?] %s not found. Skipped.\n', item);
        end
    end

    % 3. Save path    
    if savepath == 0
        disp('>> Success.');
        
        % 4. Display Info Banner
        disp(' ');
        disp('   ==============================================================================');
        fprintf('   Welcome to PowerBiMIP V0.1.0 | (c) 2025 Yemin Wu, Southeast University\n');
        fprintf('   Open-source, efficient tools for power and energy system bilevel mixed-integer programming.\n');
        disp('   ------------------------------------------------------------------------------');
        fprintf('   GitHub: https://github.com/GreatTM/PowerBiMIP\n');
        fprintf('   Docs:   https://docs.powerbimip.com\n');
        disp('   ================================================================================');
        disp(' ');

        % The gentle push to read docs
        disp('>> Pro tip: Highly recommend reading the Docs before you panic.');
        disp('>> Now go break some code. Wishing you smooth programming!');
    else
        disp('>> Failed to save permanently (Permission denied).');
        disp('>> It works for NOW, but paths will vanish when you restart.');
        disp('>> Fix: Run MATLAB as Administrator and try again.');
    end
    
    disp(' ');
end