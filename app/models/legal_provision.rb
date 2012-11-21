class LegalProvision < ActiveRecord::Base

  # Associations
  belongs_to :clause
  def self.store_legal_items(params)
    #args = args.extract_options!
    #~ self.create(:arbitration_clause => args[:arbitration_clause], :mediation_clause => args[:mediation_clause], :recording_of_clause => args[:recording_of_clause], :release_clause => args[:release_clause], :ownership_and_removal => args[:ownership_and_removal], :clause_id =>args[:clause_id])
    self.create(:arbitration_clause => params[:arbitration_clause], :mediation_clause => params[:mediation_clause], :recording_of_clause => params[:recording_of_clause], :release_clause => params[:release_clause], :ownership_and_removal => params[:ownership_and_removal], :clause_id =>params[:clause_id])
  end
end
