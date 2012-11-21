class TemplateFolderCollabsController < ApplicationController
  # GET /template_folder_collabs
  # GET /template_folder_collabs.xml
  def index
    @template_folder_collabs = TemplateFolderCollab.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @template_folder_collabs }
    end
  end

  # GET /template_folder_collabs/1
  # GET /template_folder_collabs/1.xml
  def show
    @template_folder_collab = TemplateFolderCollab.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @template_folder_collab }
    end
  end

  # GET /template_folder_collabs/new
  # GET /template_folder_collabs/new.xml
  def new
    @template_folder_collab = TemplateFolderCollab.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @template_folder_collab }
    end
  end

  # GET /template_folder_collabs/1/edit
  def edit
    @template_folder_collab = TemplateFolderCollab.find(params[:id])
  end

  # POST /template_folder_collabs
  # POST /template_folder_collabs.xml
  def create
    @template_folder_collab = TemplateFolderCollab.new(params[:template_folder_collab])

    respond_to do |format|
      if @template_folder_collab.save
        format.html { redirect_to(@template_folder_collab, :notice => 'Template folder collab was successfully created.') }
        format.xml  { render :xml => @template_folder_collab, :status => :created, :location => @template_folder_collab }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @template_folder_collab.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /template_folder_collabs/1
  # PUT /template_folder_collabs/1.xml
  def update
    @template_folder_collab = TemplateFolderCollab.find(params[:id])

    respond_to do |format|
      if @template_folder_collab.update_attributes(params[:template_folder_collab])
        format.html { redirect_to(@template_folder_collab, :notice => 'Template folder collab was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @template_folder_collab.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /template_folder_collabs/1
  # DELETE /template_folder_collabs/1.xml
  def destroy
    @template_folder_collab = TemplateFolderCollab.find(params[:id])
    @template_folder_collab.destroy

    respond_to do |format|
      format.html { redirect_to(template_folder_collabs_url) }
      format.xml  { head :ok }
    end
  end
end
