class_name CrookedMoonLook
extends CampaignLook
## The Crooked Moon's scenery for the engine's world code (CampaignLook, named in data/campaign.json). Empty on purpose: the
## base class builds no set piece. Plan G8 fills it in: the Crooked Moon in every sky, the Oak of Many Faces, the Crooked
## House's bend and morph, the Ghostlight Express, the Wicker Man, the Crooked Tree and its barrow.


## Coming out of the mist between the Ghostlight Express's cars into the next one (E23): the Narrator says the car has changed before the
## car's own words. The place the party left is still the story's `location` here (LocationView sets the new one just after).
func dress_place(view: LocationView) -> void:
	if view.st.location == CrookedMoonCampaign.limbo_place() and CrookedMoonCampaign.is_car(view.loc_id):
		view._say("switcheroo:arrive")
