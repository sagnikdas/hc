Create a new branch from the main branch. Name it "feature/hc_audios_upgrade_chanting"
In the Home scree, Sacred Melodies section, On click of the Hanuman Chalisa tile, it should show a screen to select from a list of options to play the Hanuman chalisa. There are 2 new recitations I have cretated (male/female) audio chanting hanumanchalisa. So, the previous song and these 2 options should show in the screen for the user to select their choice. for first time user. Next time onwards, they dont have to go to this screen mandatorily to play the chalisa. The preselected one, would play automatically.
But, the user should have an option to switch to a new audio track, incase he/she wishes to. In that case, the audio would start from the beginning of the new selected audio.
The option to select a diff audio track will be on the pay screen. Figure a way to squeeze in this ui component.
Due to te changes in the audio tracks, the corresponding LRC file used in the automatic lyrics rundown with the song will also have to be loaded individually fo the specific audio selected. So, that the feature of automatic lyrics rundown withthe song or the recitations work seamlessly.
For the recitations male/female audio tracks, we have created it using an ssml file. The path to it is /Users/sagnikdas/pphc/backend/hanuman_chalisa.ssml 
This has the exact times when the pauses happen etc. So, I want you to generate corresponding LRC files as per this for the corresponding audio tracks.
Here are the audio tracks:
/Users/sagnikdas/Downloads/hanuman_chalisa_voices/hc_female_final.mp3
/Users/sagnikdas/Downloads/hanuman_chalisa_voices/hc_male_final.mp3
Although the above 2 files are created using same ssml file, the durations are uneven so I doubt if the ssml file will help. But keep your options open and ways sharp to get the inidividual LRC files being generated. The lyrics rundown should be seamless.


