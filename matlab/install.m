function install()
% INSTALL Sets up PowerBiMIP.
% Adds the necessary folders to your path and sweeps out path entries

    disp(' ');
    disp('>> PowerBiMIP Installer started.');
    disp('>> Let''s see where we are...');

    % 1. This script lives in <repo>/matlab/ — that is our root
    root = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(root);
    fprintf('   Root detected: %s\n', root);

    % 2. Sweep stale entries from the old layout (before the monorepo
    %    move, src/config/examples sat at the repository root)
    disp('>> Sweeping stale entries from your path...');
    entries = strsplit(path, pathsep);
    prefix = [repoRoot filesep];
    cleaned = 0;
    for k = 1:numel(entries)
        entry = entries{k};
        if startsWith(entry, prefix) && ~isfolder(entry)
            rmpath(entry);
            cleaned = cleaned + 1;
        end
    end
    if cleaned > 0
        fprintf('   [-] Removed %d stale entries from the old layout.\n', cleaned);
    else
        disp('   [=] Nothing stale. Clean.');
    end

    % 3. Folders to add
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

    if found_count == 0
        disp('>> Hmm, none of the expected folders were found.');
        disp('>> Make sure install.m sits inside the matlab/ folder of the PowerBiMIP repo.');
        disp(' ');
        return;
    end

    % 4. Version comes from the VERSION file (single source of truth)
    version = '(unknown version)';
    versionFile = fullfile(root, 'VERSION');
    if isfile(versionFile)
        version = strtrim(fileread(versionFile));
    end

    % 5. Save path
    if savepath == 0
        disp('>> Success.');

        % 6. Display Info Banner
        disp(' ');
        disp('   ==============================================================================');
        fprintf('   Welcome to PowerBiMIP %s | (c) 2026 Yemin Wu, Southeast University\n', version);
        fprintf('   Open-source, efficient tools for power and energy system bilevel mixed-integer programming.\n');
        disp('   ------------------------------------------------------------------------------');
        fprintf('   GitHub: https://github.com/GreatTM/PowerBiMIP\n');
        fprintf('   Docs:   https://docs.powerbimip.com\n');
        disp('   ==============================================================================');
        disp(' ');

        % The gentle push to read docs
        disp('>> Pro tip: Highly recommend reading the Docs before you panic.');
        disp('>> Now go break some code. Wishing you smooth programming!');
    else
        disp('>> Failed to save permanently (Permission denied).');
        disp('>> It works for NOW, but paths will vanish when you restart.');
        disp('>> Fix: check the write permission of your pathdef.m and try again.');
    end

    disp(' ');
end